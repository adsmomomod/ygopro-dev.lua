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
-- Effectの各要素に対応するアクセサを作ってやる
--
local eclass_prop = dev.new_named_class("effect_class_property",
{
	__init = function( self, args )
		self.name = args[1]
		self.varname = "__var"..self.name
		self.arith = args.arith
		
		local cstpfx=args.constant
		if type(cstpfx)=="function" then
			self.constpfx = cstpfx
		elseif type(cstpfx)=="string" then
			self.constpfx = function(s) return string.match(s, cstpfx) end
		end
		
		self.altset = args.altset
	end,
	
	Register = function( self, ecl )
		-- Getter
		ecl["Get"..self.name] = function( s )
			local t = s[self.varname]
			if t==nil then return nil end
			return table.unpack(t)
		end
		
		-- Setter
		local setter = self.altset
		if setter==nil then setter="Set"..self.name end
		ecl[setter] = function( s, ... )
			local t = {...}
			if #t==0 then t=nil end
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
			if ecl._dbgmode~=nil then 
				dev.print( "SetupEffect[", self.name, "]: ", dev.valstr(t) ) 
			end
			local setterapi=Effect["Set"..self.name]
			setterapi( e, table.unpack(t) )
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
	__init = function( self, args )
		args.altset = "SetRaw"..args[1].."Handler"
		dev.super_init( self, args )
		self.handlername = self.name.."Handler"
	end,
	
	Register = function( self, ecl )
		dev.super_call( self, "Register", ecl )
	
		local setter = "Set"..self.handlername
		ecl[setter] = function( s, v )
			s[self.handlername] = v
			s:EnableHandler( handler_timing[self.name] )
			return s
		end
	end,
	
	Build = function( self, ecl )
		local t=ecl[self.varname]
		if t~=nil then return end
		
		local raw_handler=ecl:GetDefRawHandler( self.name )
		if raw_handler~=nil then
			ecl[self.varname]={raw_handler}
		end
	end,
})


-- effect_classのプロパティリスト
local eclass_prop_list = 
{
	eclass_prop{ "Code", constant=function(s) 
		if string.match(s,"^EVENT_") then 
			return true
		elseif string.match(s,"^EFFECT_") then
			return not string.match(s,"^EFFECT_TYPE_") and not string.match(s,"^EFFECT_COUNT_CODE_")
		end
		return false
	end },
	eclass_prop{ "Type", constant="^EFFECT_TYPE_", arith=true },
	eclass_prop{ "Category", constant="^CATEGORY_", arith=true },
	eclass_prop{ "Property", constant="^EFFECT_FLAG_", arith=true },
	eclass_prop{ "Range", constant=function(s)
		return string.match(s,"^LOCATION_") and not string.match(s,"^LOCATION_REASON")
	end, arith=true },
	eclass_prop{ "CountLimit", constant="^EFFECT_COUNT_CODE_" },
	eclass_prop{ "HintTiming", constant="^TIMING_", arith=true },
	eclass_prop{ "Label" },
	eclass_prop{ "LabelObject" },
	eclass_prop{ "Reset", constant="^RESET_", arith=true },
	eclass_prop{ "TargetRange", altset="RawSetTargetRange" },
	eclass_prop{ "AbsoluteRange", altset="RawSetAbsoluteRange" },
	eclass_prop{ "Description", altset="RawSetDescription" },
	eclass_prop{ "OwnerPlayer" },
	eclass_handler_prop{ "Condition" },
	eclass_handler_prop{ "Cost" },
	eclass_handler_prop{ "Target" },
	eclass_handler_prop{ "Operation" },
	eclass_handler_prop{ "Value" },
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
	
	--
	SetSingleEffect = function( self )
		self:ReplaceType( EFFECT_TYPE_FIELD, EFFECT_TYPE_SINGLE )
	end,
	SetFieldEffect = function( self )
		self:ReplaceType( EFFECT_TYPE_SINGLE, EFFECT_TYPE_FIELD )
	end,
	
	--
	SetSingleRange = function( self, val )		
		self:SetSingleEffect()
		self:AddProperty( EFFECT_FLAG_SINGLE_RANGE )
		self:SetRange( val )
	end,
	SetTargetRange = function( self, val, player, absolute )
		self:SetFieldEffect()
		if absolute then
			self:RawSetAbsoluteRange( absolute, player:FormatRange(val) )
		else
			self:RawSetTargetRange( player:FormatRange(val) )
		end
	end,
	SetTargetPlayerRange = function( self, player, absolute )
		self:SetTargetRange( 1, player, absolute )
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
		self:AddReset( RESET_EVENT+RESET_PHASE+ph )
	end,
	SetResetLeaveZone = function( self )
		self:AddReset( RESET_EVENT+0x1fe0000 )
	end,
	
	-- 対象をとる
	SetTakeTarget = function(self)
		self:AddProperty( EFFECT_FLAG_CARD_TARGET )
	end,
	IsTakeTarget = function(self)
		return self:TestProperty( EFFECT_FLAG_CARD_TARGET )
	end,
	
	SetOath = function(self)
		self:AddProperty( EFFECT_FLAG_OATH )
	end,
	
	-- 
	SetValue = function(self, v)
		if type(v)=="function" then
			self:SetValueHandler(v)
		else
			self:SetRawValueHandler(v)
		end
	end,
	
	--
	-- オペレーション関連
	--	
	-- オペレーションを登録
	AddOperation = function( self, op, timing )
		table.insert( self._ops, {timing, op} )
		self:EnableHandler( timing )
		
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
		self:EnableHandler( timing )
		return op
	end,
	AddCond = function( self, op )
		self:AddRequired( op, dev.oncond )
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
	GetDefRawHandler = function( self, name )
		if self[name]~=nil or self._autogen[name]~=nil then
			local ctl_handler=self[name.."Handler"]
			local timing=handler_timing[name]
			return function(...) 
				local est = dev.effect_state( self, timing )
				self:InitStateObject( est, ... )
				return ctl_handler( est, self ) 
			end
		end
		return nil
	end,
	
	-- 自動生成すべきハンドラを宣言する
	EnableHandler = function( self, tim )
		for k, v in pairs( handler_timing ) do
			if bit.btest( v, tim ) then
				self._autogen[k] = true
			end
		end
	end,
	
	-- condition
	ConditionHandler = function( est, self )		
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
	CostHandler = function( est, self )
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
	TargetHandler = function( est, self )
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
	OperationHandler = function( est, self )
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
	ValueHandler = function( est, self )
		return dev.Eval( self.Value, est )
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

-- 
function dev.HandlerFromFilter(filter)
	return function(est) return filter( est:GetTarget(), est ) end
end

-- 効果クラスのデバッグ表示
function dev.print_effect_class( e, ename )
	ename=dev.option_arg(ename,"e")
	dev.print(" >>> Effect "..ename.." <<< ")
	if e==nil then dev.print(" = nil") end 
	
	for _, prop in ipairs( eclass_prop_list ) do
		local s, ret = prop:Format( e )
		if s and ret then
			dev.print( prop.name, " = ", s )
		end
	end
end

--
-- コンストラクタや効果クラスから実際に効果を作成・登録
--

-- 効果コンストラクタから、新しい空の効果クラスを作成
function dev.CreateEffectClass( eclassiniter, cdata, ... )
	local args = table.pack(...)
	local ec=dev.effect_class( cdata )
	eclassiniter( ec, table.unpack(args) )
	return ec
end

-- 
function dev.BindEffectIniter( eclassiniter, ... )
	local args = table.pack(...)
	return function( self )
		return eclassiniter( self, table.unpack(args) )
	end
end	

-- 効果コンストラクタやユーザーが作った効果クラスを、ビルド済み効果クラスに変換
function dev.BuildEffectClass( eclass, cdata )
	if type(eclass)=="table" and eclass._isbuilt==true then
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
	
	eclass._isbuilt = true -- ハンドラ等の生成が済んだものとそうでないものを区別
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
	dev.require( eclass, "table" )
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
Card.RegisterEffectClass = dev.RegisterEffect

--
--  プリセットの効果クラスを格納
--
dev.effect = {}

dev.new_effect = {}
setmetatable( dev.new_effect, { __index = function( tbl, name )
	return dev.CreateEffectClass( rawget( dev.effect, name ) )
end })





