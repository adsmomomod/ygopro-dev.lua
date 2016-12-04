
--
-- ====================================================
--
-- !! 効果
--
-- ====================================================
--
-- 引数をパック
--
dev.effect_state = dev.new_class(
{
	__init = function( self, ec, tim ) 
		self.eclass = ec
		self.timing = tim
		
		self.curop = 0
		self.opst = {}
		self.pies = {}
		
		self.tg = {}
		self.args = {}
	end,
	GetEffect = function(self)
		return self.effect
	end,
	GetHandler = function(self)
		return self:GetEffect():GetHandler()
	end,
	GetLabelObject = function(self)
		return self:GetEffect():GetLabelObject()
	end,
	SetLabelObject = function(self, v)
		return self:GetEffect():SetLabelObject(v)
	end,
	
	GetTarget = function( self )
		return self.tc
	end,
	GetTargetPlayer = function( self )
		return self.tp
	end,
	
	GetTimingReason = function(self)
		return self.eclass:GetOperationReason( self )
	end,
	
	GetEffectClass = function(self)
		return self.eclass
	end,
	
	--
	-- 現在のオペレーションをスタックにつむ
	-- _はライブラリ内でのみ使用
	--
	pushOpState = function( self, key, state )
		self.curop=key
		if self.opst[key]==nil then
			self.opst[key]=state
		end
		return self.opst[key]
	end,
	
	HasOpState = function(self)
		return self:TopOpState()~=nil
	end,
	TopOpState = function(self)
		return self.opst[self.curop]
	end,
	TopOp = function(self)
		return self.opst[self.curop].op
	end,
	
	GetOpCheck = function( self, op )
		return self.opst[op.key].check
	end,
	GetOpResult = function( self, op )
		return self.opst[op.key].result
	end,
	GetOpResultOperand = function( self, op, opr )
		local r=self:GetOpResult(op)
		if r then return r:GetOperand(opr) end
		return nil
	end,
	
	InvokeOp = function( self, op, fn )
		local cop=self.curop
		if op then
			self.curop=op.key
		else
			self.curop=nil
		end		
		local cag=dev.table.deepcopy(self.args)
		
		local r=fn( op, self )
		
		self.curop=cop
		self.args=cag
		return r
	end,
	
	--
	-- パイ
	--
	GetPieCounter = function(self, key)
		local pi = self.pies[key]
		if pi==nil then
			self:OpDebugDisp("key=",key,"のパイカウンターが作成されていません")
		end
		return pi
	end,	
	addPieCounter = function(self, pie)
		local ni = dev.pie_counter(pie)
		ni:Reset( self )
		self.pies[pie.key] = ni 
	end,
	
	--
	-- 対象
	-- 
	GetActivationTarget = function(self, idx)
		return self.tg[idx]
	end,
	setActivationTarget = function(self, tgs)
		self.tg=tgs
	end,
	
	--
	--
	--
	IsOperable = function( self, ... )
		local opst=self:TopOpState()
		if opst then
			return opst.op:chkOperableObject( self, ... )
		end
		return true
	end,
	
	IsOperableSep = function( self, o )
		local opst=self:TopOpState()
		if opst then
			return opst.op:chkOperableObjectSep( self, o, opst.operand )
		end
		return true
	end,
	

	-- デバッグ関数
	OpDebugDisp = function(self, ...)
		if self:HasOpState() then
			self:TopOp():DebugDisp(self, ...)
		end
	end
})
function dev.IsHandlerCard( c, est )
	return c==est:GetHandler()
end
function dev.IsOperable( est, ... )
	return est:IsOperable(...)
end 

-- 
dev.operation_state = dev.new_class(
{
	__init = function(self, op, args, pie)
		self.op = op
		self.operand = 1
		self.args = args
		self.check = false
		self.result = nil
	end,
	
	setCurOperand = function( self, opr )
		self.operand = opr
	end,
	setArgument = function( self, args )
		self.args = args
	end,
	setResult = function( self, r )
		self.result = r
	end,
	setCheckResult = function( self, r )
		self.check = r
	end,
})

--
--
-- 効果クラス
--
--
dev.eclass_prop = dev.new_class(
{
	__init = function( self, name, constpfx, arith, setter )
		self.name = name
		self.varname = "__var"..name
		self.arith = arith
		if setter then
			self.setterapi = setter
		else
			self.setterapi = Effect["Set"..self.name]
		end
		
		if type(constpfx)=="function" then
			self.constpfx = constpfx
		elseif type(constpfx)=="string" then
			self.constpfx = function(s) return string.match(s, constpfx) end
		end
	end,
	
	Register = function( self, ecl )
		-- Getter / Setter
		ecl["Get"..self.name] = function( s )
			local t = s[self.varname]
			if t==nil then return nil end
			return table.unpack(t)
		end
		ecl["Set"..self.name] = function( s, ... )
			local t = {...}
			if #t==0 then
				t = nil
			end
			s[self.varname] = t
			return s
		end
	
		-- 数値のプロパティに対して
		if self.arith then
			ecl["Add"..self.name] = function( s, v )
				local t = s[self.varname]
				if t==nil then t={0} end				
				if v then
					t[1] = bit.bor( t[1], v )
					s[self.varname] = t
				end
				return s
			end
			ecl["Replace"..self.name] = function( s, rem, add )
				local t = s[self.varname]
				if t==nil then t={0} end
				if rem and add then
					local v = bit.band( t[1], bit.bnot(rem) )
					t[1] = bit.bor( v, add )
					s[self.varname] = t
				end
				return s
			end
			ecl["Test"..self.name] = function( s, val )
				local t = s[self.varname]
				if t==nil then return false end
				return bit.btest( t[1], val )
			end
		end
	end,
	
	-- 
	SetupEffect = function( self, ecl, e )
		local t = ecl[self.varname]
		if t~=nil then
			self.setterapi( e, table.unpack(t) )
		end
	end,
	
	Format = function( self, e )
		local getter=e["Get"..self.name]
		if getter==nil then return "" end
		
		local ret = (select(1, getter( e )))
		
		local s
		if self.arith and ret then
			s = string.format( "0x%x", ret )
		else
			s = tostring( ret )
		end
		
		if ret and self.constpfx then
			local names={}
			for name, value in pairs(_G) do
				if self.constpfx( name ) then
					if self.arith then
						if bit.btest( ret, value ) then 
							table.insert( names, name )
						end
					elseif value == ret then
						table.insert( names, name )
						break
					end
				end
			end
			s = s.." ("..table.concat(names,"+")..")"
		end
		return s, ret
	end,
})
dev.eclass_ctl_handler_prop = dev.new_class(dev.eclass_prop,
{
	__init = function( self, name )
		dev.super_init( self, name )
	end,
	
	Build = function( self, ecl )
		local t = ecl[self.varname]
		if t==nil then
			local f = ecl:GenerateControlHandler( self.name )
			if f~=nil then
				ecl[self.varname] = {f}
			end
		end
	end,
})

-- effect_classのプロパティリスト
local eclass_prop_list = 
{
	dev.eclass_prop( "Code", function(s) 
		if string.match(s,"^EVENT_") then 
			return true
		elseif string.match(s,"^EFFECT_") then
			return not string.match(s,"^EFFECT_TYPE_") and not string.match(s,"^EFFECT_COUNT_CODE_")
		end
		return false
	end ),
	dev.eclass_prop( "Type", "^EFFECT_TYPE_", true ),
	dev.eclass_prop( "Category", "^CATEGORY_", true ),
	dev.eclass_prop( "Property", "^EFFECT_FLAG_", true ),
	dev.eclass_prop( "Range", function(s)
		return string.match(s,"^LOCATION_") and not string.match(s,"^LOCATION_REASON")
	end, true ),
	dev.eclass_prop( "CountLimit", "^EFFECT_COUNT_CODE_" ),
	dev.eclass_prop( "AbsoluteRange" ),
	dev.eclass_prop( "HintTiming", "^TIMING_", true ),
	dev.eclass_prop( "Label" ),
	dev.eclass_prop( "LabelObject" ),
	dev.eclass_prop( "Reset", "^RESET_", true ),
	dev.eclass_prop( "TargetRange" ),
	dev.eclass_prop( "OwnerPlayer" ),
	dev.eclass_prop( "Description", nil, false, 
		function(e, cid, id) 
			local sid=cid
			if id~=nil then sid = aux.Stringid(cid,id) end
			e:SetDescription(sid)
		end ),
	dev.eclass_ctl_handler_prop( "Condition" ),
	dev.eclass_ctl_handler_prop( "Cost" ),
	dev.eclass_ctl_handler_prop( "Target" ),
	dev.eclass_ctl_handler_prop( "Operation" ),
	dev.eclass_ctl_handler_prop( "Value" ),
}

--
local handler_timing = 
{
	Condition = dev.oncond,
	Cost = dev.oncost,
	Target = dev.ontarget,
	Operation = dev.onoperation,
	Value = dev.onvalue,
}

--
--
-- effect_class
--
--
dev.effect_class = dev.new_class(
{	
	__init = function( self, cdata )
		self._pies = {}
		self._req = {}
		self._ops = {} 
		self._autogen = {}
		
		-- アクセサを登録
		for _, prop in ipairs(eclass_prop_list) do
			prop:Register( self )
		end
		
		-- カード情報を記録
		self.Card = cdata -- id, type
		if self.Card then
			if bit.btest( self.Card.type, TYPE_MONSTER ) then
				self:SetRange(LOCATION_MZONE)
			else
				self:SetRange(LOCATION_SZONE)
			end
		end
	end,
	
	-- 効果登録に関するパラメータ
	SetPlayerEffect = function(self, p)	self._playere = p 	return self end,
	SetForced 		= function(self)	self._forced = true return self end,
	
	-- count
	SetCountLimitByName = function( self, cnt )
		cnt=dev.option_arg(cnt, 1)
		if self.Card then
			self:SetCountLimit( cnt, self.Card.id )
		end
	end,
	
	-- reset
	SetResetPhase = function( self, ph )
		return self:AddReset( RESET_EVENT+RESET_PHASE+ph )
	end,
	SetResetLeaveZone = function( self, ph )
		self:AddReset( RESET_EVENT+0x1fe0000 )
		if ph~=nil then self:SetResetPhase(ph) end
		return self
	end,
	
	-- 対象をとる
	SetTakeTarget = function(self)
		local r=self:AddProperty( EFFECT_FLAG_CARD_TARGET )
	end,
	IsTakeTarget = function(self)
		return self:TestProperty( EFFECT_FLAG_CARD_TARGET )
	end,
	
	--
	-- オペレーション関連
	--	
	-- オペレーションを登録
	AddOperation = function( self, op, timing )
		table.insert( self._ops, {timing, op} )
		self:enableAutoGen( timing )
		
		-- キー発行
		op.key = #self._ops + 100
		return op
	end,
		
	-- デフォルトの自動処理
	ProcessOps = function( self, est )
		for i, ent in ipairs(self._ops) do
			local exec_tim = ent[1]
			
			if bit.btest( exec_tim, est.timing ) then
				local op = ent[2]
				op:Execute( est )
			end
		end
	end,
	
	-- 必須条件を登録
	AddRequired = function( self, op, timing )
		table.insert( self._req, {timing, op} )
		self:enableAutoGen( timing )
		return op
	end,
	
	-- 発動可能かチェック
	CheckRequiredCondition = function( self, est )
		for i, entry in ipairs(self._req) do
			local check_tim=entry[1]
			local op=entry[2]
			
			-- check_timingに応じて呼び出す
			if bit.btest( check_tim, est.timing ) then
				local chk=false
				if type(op)=="table" and op.Check then
					chk=op:Check( est )
				else
					chk=dev.eval( op, est )
				end
				if chk==false then
					return false
				end
			end
		end
		return true
	end,
	
	-- 自動生成すべきハンドラを記録する
	enableAutoGen = function( self, tim )
		if self._autogen[tim] == true then
			return
		end
		for k, v in pairs( handler_timing ) do
			if bit.btest( v, tim ) then
				self._autogen[k] = true
			end
		end
	end,
	
	--
	-- Pie関連
	--
	AddPie = function( self, pie )
		table.insert( self._pies, pie )
		pie.key = #self._pies + 500
		return pie
	end,
	
	ResetPies = function( self, est, key )
		for i, pie in ipairs( self._pies ) do
			if key==nil or key==pie.key then
				est:addPieCounter( pie )
			end
		end		
	end,
	
	CheckPies = function( self, est, key )
		for k, pieinst in pairs( est.pies ) do
			if key==nil or k==(key.."") then
				if not pieinst:Check() then return false end
			end
		end
		return true
	end,	
	
	--
	-- ハンドラ
	--
	-- デフォルトのハンドラを生成
	GenerateDefaultHandler = function( self, name )
		if self._autogen[name]==nil then return nil end
		return function(est) self:ProcessOps(est) end
	end,
	
	-- Effectに設定する大域のハンドラを生成
	GenerateControlHandler = function( self, name )
		if self[name]==nil then
			self[name]=self:GenerateDefaultHandler(name)
		end
		if self[name]~=nil then
			local ctl_handler=self[name.."Handler"]
			local timing=handler_timing[name]
			
			return function(...) 
				local est = dev.effect_state( self, timing )
				self:InitStateObject( est, ... )
				return ctl_handler( self, est ) 
			end
		end
	end,
	
	--
	-- 効果オブジェクトに渡すハンドラ関数
	--
	-- condition
	ConditionHandler = function( self, est )
		self:DebugDisp("SetCondition Func Called (do)", est)
		
		self:ResetPies( est )
		if not self:CheckRequiredCondition( est ) then 
			self:DebugDisp("使用条件が満たされていません", est)
			return false
		elseif not self:CheckPies( est ) then 
			self:DebugDisp("Condition Pieが足りません", est)
			return false 
		end
		
		return true
	end,
	
	-- cost
	CostHandler = function( self, est )
		self:ResetPies( est )
		if est.chk then	
			self:DebugDisp("SetCost Func Called (chk)", est)
			if not self:CheckRequiredCondition( est ) then 
				self:DebugDisp("コスト支払い条件が満たされていません", est)
				return false 
			elseif self.CheckCost and not self.CheckCost(est) then 
				self:DebugDisp("CheckCostがfalseを返しました", est)
				return false 
			elseif not self:CheckPies( est ) then 
				self:DebugDisp("Cost Pieが足りません", est)
				return false 
			end
			return true
		end
		self:DebugDisp("SetCost Func Called (do)", est)
		return self.Cost(est)
	end,
	
	-- target
	TargetHandler = function( self, est )	
		self:ResetPies( est )	
		if est.chkc then
			self:DebugDisp("SetTarget Func Called (chkc)", est)
			if not self:CheckRequiredCondition( est ) then return false end
			if self.CheckTargetCard then return self.CheckTargetCard( est, est.chkc )
			else return true end
		elseif est.chk then
			self:DebugDisp("SetTarget Func Called (chk)", est)
			if not self:CheckRequiredCondition( est ) then 
				self:DebugDisp("発動/使用条件が満たされていません", est)
				return false
			elseif self.CheckTarget and not self.CheckTarget(est) then
				self:DebugDisp("CheckTargetがfalseを返しました", est)
				return false
			elseif not self:CheckPies( est ) then 
				self:DebugDisp("Target Pieが足りません", est)
				return false 
			end
			return true
		end
		
		self:DebugDisp("SetTarget Func Called (do)", est)
		return self.Target(est)
	end,
	
	-- operation
	OperationHandler = function( self, est )
		self:DebugDisp("SetOperation Func Called (do)", est)
		
		if self:IsTakeTarget() then
			local tgs=self:ObtainTarget( est )
			est:setActivationTarget(tgs)
			--dev.print_table(tgs,"tgs")
		end
		
		self:ResetPies( est )
		if not self:CheckRequiredCondition( est ) then 
			self:DebugDisp("効果適用条件が満たされていません", est)
			return nil 
		elseif not self:CheckPies( est ) then 
			self:DebugDisp("Operation Pieが足りません", est)
			return nil
		end
		
		self:ResetPies( est )
		return self.Operation( est )
	end,
	
	-- value
	ValueHandler = function( self, est )
		return self.Value( est:GetTarget(), est )
	end,
	
	--
	-- デバッグ表示
	--
	Debug = function( self )
		self._dbgmode=true
	end,
	DebugDisp = function( self, msg, est )
		if self._dbgmode then
			dev.print( msg )
		end
	end,
	
	--
	RegisterToCard = function( self, c )
		return dev.RegisterEffect( c, self )
	end,
})

-- EffectClassを作成
function dev.BuildEffectClass( initer, cdata )
	
	-- ユーザー定義のコンストラクタを実行
	local inst = dev.effect_class(cdata)
	initer( inst )
	
	-- プロパティを抽出し設定
	for _, prop in ipairs( eclass_prop_list ) do
		if prop.Build~=nil then
			prop:Build( inst )
		end
	end
	
	-- デバッグ表示
	if inst._dbgmode then
		dev.print( " 作成された効果クラス：" )
		dev.print_effect_class( inst )
	end
	
	return inst	
end

-- EffectClassから効果オブジェクトを作成
function dev.CreateEffect( eclass, c )
	local e = nil
	if not c then
		e = Effect.GlobalEffect()
	else
		e = Effect.CreateEffect(c)
	end
	
	-- プロパティを抽出し設定
	for _, prop in ipairs( eclass_prop_list ) do
		prop:SetupEffect( eclass, e )
	end

	return e
end

-- デバッグ表示
function dev.print_effect_class( e, ename )
	ename=dev.option_arg(ename,"e")
	dev.print(" >>> Effect "..ename.." <<< ")
	
	for _, prop in ipairs( eclass_prop_list ) do
		local s, ret = prop:Format( e )
		if s and ret then
			dev.print( prop.name, " = ", s )
		end
	end
end

-- 作成 & 登録
function dev.RegisterEffect( c, eclass )
	local e = dev.CreateEffect( eclass, c )
	if eclass._playere~=nil then
		Duel.RegisterEffect(e, eclass._playere)
	else
		c:RegisterEffect(e, dev.option_arg(eclass._forced, false) )
	end
	return e, eclass
end
function dev.RegisterNewEffect( c, eclassctor )
	local eclass = dev.BuildEffectClass( eclassctor, { type=c:GetType(), id=c:GetCode(), } )
	return dev.RegisterEffect( c, eclass )
end




