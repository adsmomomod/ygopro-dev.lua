--
-- Effectの各要素に対応するアクセサを作ってやる
--
local eclass_prop = dev.new_named_class("effect_class_property",
{
	__init = function( self, name, constpfx, arith )
		self.name = name
		self.varname = "__var"..name
		self.arith = arith
		
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
		ecl["RawSet"..self.name] = ecl["Set"..self.name]
	
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
			local setterapi=Effect["Set"..self.name]
			setterapi( e, table.unpack(t) )
			
			if ecl._dbgmode~=nil then 
				dev.print( "SetupEffect[", self.name, "]: ", dev.valstr(t) ) 
			end
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

local eclass_handler_prop = dev.new_named_class("effect_class_handler_property", eclass_prop,
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
	eclass_prop( "Code", function(s) 
		if string.match(s,"^EVENT_") then 
			return true
		elseif string.match(s,"^EFFECT_") then
			return not string.match(s,"^EFFECT_TYPE_") and not string.match(s,"^EFFECT_COUNT_CODE_")
		end
		return false
	end ),
	eclass_prop( "Type", "^EFFECT_TYPE_", true ),
	eclass_prop( "Category", "^CATEGORY_", true ),
	eclass_prop( "Property", "^EFFECT_FLAG_", true ),
	eclass_prop( "Range", function(s)
		return string.match(s,"^LOCATION_") and not string.match(s,"^LOCATION_REASON")
	end, true ),
	eclass_prop( "CountLimit", "^EFFECT_COUNT_CODE_" ),
	eclass_prop( "AbsoluteRange" ),
	eclass_prop( "HintTiming", "^TIMING_", true ),
	eclass_prop( "Label" ),
	eclass_prop( "LabelObject" ),
	eclass_prop( "Reset", "^RESET_", true ),
	eclass_prop( "TargetRange" ),
	eclass_prop( "OwnerPlayer" ),
	eclass_prop( "Description" ),
	eclass_handler_prop( "Condition" ),
	eclass_handler_prop( "Cost" ),
	eclass_handler_prop( "Target" ),
	eclass_handler_prop( "Operation" ),
	eclass_handler_prop( "Value" ),
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
		if self.Card and self.Card.type then
			if bit.btest( self.Card.type, TYPE_MONSTER ) then
				self:SetRange(LOCATION_MZONE)
			else
				self:SetRange(LOCATION_SZONE)
			end
		end
	end,
	
	--
	-- パラメータ設定
	--
	-- 自身を指定のクラス型へ変換し初期化
	Construct = function( self, class, ... )
		dev.instantiate( self, class, ... )
	end,
	
	-- 用意されたビルダを実行する
	Inherit = function( self, builder )
		builder( self )
	end,
	
	-- 効果登録に関するパラメータ
	SetOwner	 = function(self, v) self._owner = v     return self end,
	SetGlobal 	 = function(self)	 self._owner = false return self end,
	SetRegForced = function(self)	 self._regforced = true return self end,
	
	GetOwner = function( self, regc )
		if self._owner==false then
			return nil
		elseif self._owner==nil and type(regc)=="number" then
			return nil
		elseif self._owner==nil then 
			return regc
		else 
			return self._owner 
		end
	end,
	
	-- count
	SetCountLimitByName = function( self, cnt )
		cnt=dev.option_arg(cnt, 1)
		if self.Card then
			self:SetCountLimit( cnt, self.Card.id )
		end
	end,
	
	-- single_range
	SetSingleRange = function( self, r )
		self:SetType( EFFECT_TYPE_SINGLE )
		self:AddProperty( EFFECT_FLAG_SINGLE_RANGE )
		self:SetRange( r )
	end,
	
	-- target_range
	SetTargetRange = function( self, val, player )
		self:SetType( EFFECT_TYPE_FIELD )
		if player==nil then player=dev.both end
		self:RawSetTargetRange( player:FormatRange(val) )
	end,
	SetTargetPlayer = function( self, player )
		self:SetTargetRange( 1, player )
		self:AddProperty( EFFECT_FLAG_PLAYER_TARGET )
	end,
	
	-- 説明
	SetDescription = function( self, cid, id )
		local sid=cid
		if id~=nil then sid = aux.Stringid(cid,id) end
		self:RawSetDescription(sid)
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
		if dev.is_class(op) then
			op.key = #self._ops + 100
		end
		return op
	end,
		
	-- 登録オペレーションを実行
	ProcessOperation = function( self, est, proc )
		est:ResetPieCounters()
		if proc then
			return proc( est )
		else
			for i, ent in ipairs(self._ops) do
				local exec_tim = ent[1]
				if bit.btest( exec_tim, est.timing ) then
					local op = ent[2]
					if type(op)=="table" and op.Execute then
						op:Execute( est )
					else
						dev.eval( op, est )
					end
				end
			end
			return nil
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
		est:ResetPieCounters()
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
	GetPies = function( self )
		return self._pies
	end,
	
	--
	-- ハンドラ
	--	
	-- Effectに設定する大域のハンドラを生成
	GenerateControlHandler = function( self, name )
		local genhandler = (self[name]~=nil or self._autogen[name])
		if genhandler==true then
			local ctl_handler=self[name.."Handler"]
			local timing=handler_timing[name]
			
			return function(...) 
				local est = dev.effect_state( self, timing )
				self:InitStateObject( est, ... )
				return ctl_handler( self, est ) 
			end
		end
	end,
	
	-- condition
	ConditionHandler = function( self, est )		
		if not self:CheckRequiredCondition( est ) then 
			self:DebugDisp("使用条件が満たされていません", est)
			return false
		elseif not est:CheckPieCounters() then 
			self:DebugDisp("Condition Pieが足りません", est)
			return false 
		end
		
		if self.Condition then 
			est:ResetPieCounters()
			return self:Condition(est) 
		end
		return true
	end,
	
	-- cost
	CostHandler = function( self, est )
		if est.chk then
			if not self:CheckRequiredCondition( est ) then 
				self:DebugDisp("コスト支払い条件が満たされていません", est)
				return false 
			elseif self.CheckCost and not self.CheckCost(est) then 
				self:DebugDisp("CheckCostがfalseを返しました", est)
				return false 
			elseif not est:CheckPieCounters() then 
				self:DebugDisp("Cost Pieが足りません", est)
				return false 
			end
			return true
		end
		
		return self:ProcessOperation( est, self.Cost )
	end,
	
	-- target
	TargetHandler = function( self, est )
		if est.chkc then
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
			elseif not est:CheckPieCounters() then 
				self:DebugDisp("Target Pieが足りません", est)
				return false 
			end
			return true
		end
		
		return self:ProcessOperation( est, self.Target )
	end,
	
	-- operation
	OperationHandler = function( self, est )
		self:DebugDisp("SetOperation Func Called (do)", est)
		
		if self:IsTakeTarget() then
			local tgs=self:ObtainTarget( est )
			est:setActivationTarget(tgs)
			--dev.print_table(tgs,"tgs")
		end
		
		if not self:CheckRequiredCondition( est ) then 
			self:DebugDisp("効果適用条件が満たされていません", est)
			return nil 
		elseif not est:CheckPieCounters() then 
			self:DebugDisp("Operation Pieが足りません", est)
			return nil
		end
		
		return self:ProcessOperation( est, self.Operation )
	end,
	
	-- value
	ValueHandler = function( self, est )
		return self.Value( est )
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

-- 効果クラスのデバッグ表示
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

-- 
dev.effect = {}

--
-- コンストラクタや効果クラスから実際に効果を作成・登録
--

-- 効果コンストラクタから、新しい空の効果クラスを作成
function dev.CreateEffectClass( eclassiniter, cdata )
	local ec=dev.effect_class( cdata )
	eclassiniter( ec )
	return ec
end

-- 効果コンストラクタやユーザーが作った効果クラスを、ビルド済み効果クラスに変換
function dev.BuildEffectClass( eclass, cdata )

	if type(eclass)=="table" and eclass._built==true then
		return eclass
	elseif type(eclass)=="function" then
		eclass = dev.CreateEffectClass( eclass, cdata )
	end
	
	-- ハンドラを生成する
	for _, prop in ipairs( eclass_prop_list ) do
		if prop.Build~=nil then
			prop:Build( eclass )
		end
	end
	
	eclass._built = true -- ハンドラ等の生成が済んだものとそうでないものを区別
	return eclass	
end

-- 効果クラスから効果オブジェクトを作成
function dev.CreateEffect( eclass, ec )	
	local e = nil
	if not ec then
		e = Effect.GlobalEffect()
	else
		e = Effect.CreateEffect(ec)
	end
	
	-- プロパティを抽出し設定
	for _, prop in ipairs( eclass_prop_list ) do
		prop:SetupEffect( eclass, e )
	end

	return e
end

-- 上記すべてをまとめて行う & 効果登録
function dev.RegisterEffect( c, eclass, eowner )
	eclass = dev.BuildEffectClass( eclass )
	
	if eowner==nil then eowner = eclass:GetOwner(c) end
	local e = dev.CreateEffect( eclass, eowner )
	
	if type(c)=="number" then
		Duel.RegisterEffect( e, c )
	else
		c:RegisterEffect( e, dev.option_arg(eclass._regforced, false) )
	end
	return e, eclass
end

-- Card
Card.RegisterNewEffect = dev.RegisterEffect





