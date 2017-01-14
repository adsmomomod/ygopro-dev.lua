-- 
-- ================================================================================
--
--  !! 汎用オブジェクト
--
-- ================================================================================
--
--
-- 選択されたオブジェクト
--
--[[
	*min, *max | *count : number 
	*from : object
	select_player : = you
	customhint : function = nil
	pie : = nil
	hintsel : = nil
]]--
dev.sel = dev.new_class(
{
	__init = function(self, args)	
		dev.require( args, {{ from = true }} )
		self.o = args.from
		
		self.selmin = dev.option_arg( args.min, args.count )
		self.selmax = dev.option_arg( args.max, args.count )
		self.select_player = dev.option_arg( args.player, dev.you )
		self.customhint = args.hint
		self.pie = args.pie
		self.hintsel = args.hintsel
		
		if self.selmax==nil then self.selmax=0x7FFFFFFF end
		
		dev.require( self.selmin, dev.eval_able("number") )
		dev.require( self.selmax, dev.eval_able("number") )
	end,
	
	-- インターフェース関数
	Exists = function( self, est )
		local mi, mx = self:GetMinMax( est )
		est:OperandState().min = mi
		if not self.o:Exists( est ) then
			return false
		end
		
		if self.pie then self.pie:Update( est, mi ) end
		return true
	end,
	
	-- ヒント表示、選択
	Select = function( self, est )
		local sp=dev.eval( self.select_player, est )
		local mi, mx = self:GetMinMax( est )
		
		local g=self:DoSelect( est, sp, mi, mx )
		if self.pie then self.pie:Update( est, g:GetCount() ) end
		return g
	end,
	
	GetAll = function( self, est )
		return self.o:GetAll( est )
	end,
	
	GetMinMax = function( self, est )
		local mi = dev.eval( self.selmin, est )
		local mx = dev.eval( self.selmax, est )
		if self.pie then
			mx = math.min( mx, self.pie:Get( est ) )
			mi = math.min( mi, mx )
			if mx==0 then
				est:OpDebugDisp(self,":選択可能なオブジェクトが0になりました")
			end
		end
		return mi, mx
	end,
	
	Location = function( self, est )
		return self.o:Location(est)
	end,
	
	-- メンバ関数
	DoSelect = function( self, est, sp, mi, mx )
		self:HintSelect( est, sp )
		
		est:OperandState().select_player = sp
		est:OperandState().min = mi
		est:OperandState().max = mx
		
		local g
		if self.o.SelectImpl then
			g=self.o:SelectImpl( est )
		else
			g=self.o:Select( est )
			g=g:Select( sp, mi, mx, nil )
		end
		return g
	end,
	
	HintSelect = function( self, est, tp )
		local ophint = nil
		local cop = est:CurOp()
		if cop then ophint = cop:GetHint() end
		
		if self.customhint~=nil then
			self.customhint( tp, ophint )
		else
			Duel.Hint( HINT_SELECTMSG, tp, ophint )
		end
	end,
	
	CompleteSelOptions = function( self, othersel )
		for i, name in ipairs(self.sel_options) do
			if self[name]==nil then
				self[name] = othersel[name]
			end
		end
	end,
	
	sel_options = { "from", "selmin", "selmax", "select_player", "customhint", "pie", "hintsel" }
})

--
-- 上限を超えていた場合のみ選択する
--
dev.pick_sel = dev.new_class(dev.sel,
{
	__init = function(self, args)
		if args.min==nil then args.min=1 end
		dev.super_init(self, args)
	end,
	
	-- ヒント表示、選択
	Select = function( self, est )
		local g=self.o:GetAll( est )
		
		local mi, mx=self:GetMinMax( est )
		if mx < g:GetCount() then
			local sp=dev.eval( self.select_player, est )
			g=self:DoSelect( est, sp, mi, mx )
		end
		
		if self.pie then self.pie:Update( est, g:GetCount() ) end
		return g
	end,
})

--
-- 一つ一つ選ぶ
--
dev.step_sel = dev.new_class(dev.sel,
{
	__init = function(self, args)
		dev.super_init(self, args)
		self.rel = args.binary_relation
		self.ask = dev.option_arg(args.on_proceed, self.DefOnProceed) -- function( i ) -> bool
		self.askstr = dev.option_arg(args.on_proceed_string, 560)
	end,
	
	-- 
	Exists = function( self, est, istarget )
		local all=self:GetAll(est, istarget)
		local mi, mx = self:GetMinMax(est, istarget)
		
		local hit=0
		local tc=all:GetFirst()
		while tc do
			local rem=all:Clone()
			rem:Remove(tc)
			local uc=rem:GetFirst()
			while uc do
				if self:CheckRelation(tc, uc) then
					hit = hit + 1
					if hit>=mi then
						return true
					end
				end
				uc=rem:GetNext()
			end
			tc=all:GetNext()
		end
		return false
	end,
	
	Select = function( self, est, istarget )
		local sp=dev.eval( self.select_player, est )
		local all=self:GetAll( est, istarget )
		
		local gsel=Group.CreateGroup()
		while true do
			self:HintSelect( est, sp )

			local g=self.o:Select( est, istarget, sp, 1, 1, all )
			if self.hintsel then
				Duel.HintSelection( g )
			end
			
			local c=g:GetFirst()
			gsel:AddCard(c)
			
			local mi, mx = self:GetMinMax(est)
			if mx <= gsel:GetCount() then
				break
			elseif mi <= gsel:GetCount() then
				if not self:ask( est, gsel:GetCount(), mi, mx ) then
					break
				end
			end
			all = all:Filter(function(tc) return self:CheckRelation(c,tc) end, c)
		end
		return gsel
	end,
	
	--
	CheckRelation = function( self, l, r )
		if self.rel==nil then return true end
		return self.rel(l,r)
	end,
	
	DefOnProceed = function( self, est )
		local selp=dev.eval( self.select_player, est )
		return Duel.SelectYesNo( selp, self.askstr )
	end,
})

--
-- ～を含むカードを選択
--

--
-- ランダムなカード
--
dev.random_pick = dev.new_class(dev.sel,
{
	__init = function( self, args )
		dev.super_init( self, args )
	end,
	
	-- ヒント表示、選択
	Select = function( self, est )
		local sp=dev.eval( self.select_player, est )
		self:HintSelect( est, sp )
		
		local gall=self.o:GetAll( est )
		
		local mi, mx = self:GetMinMax( est ) -- mi==mx
		local g=gall:RandomSelect( sp, mx )
		
		if self.hintsel then
			Duel.HintSelection( g )
		end
		
		if self.pie then self.pie:Update( g:GetCount() ) end
		return g
	end,
})

--
--
--
dev.allmatch = dev.new_class(dev.sel,
{
	__init = function(self, args)
		dev.super_init(self, args)
		self.o = args.from
		self.filter = args.filter
	end,
	
	Exists = function( self, est )
		local g=self.o:GetAll( est )
		return g:IsExists( self.filter, g:GetCount(), nil, est )
	end,
	
	Select = function( self, est )
		local g=self.o:GetAll( est )
		if not g:IsExists( self.filter, g:GetCount(), nil, est ) then
			g:Clear()
		end
		return g
	end,
})

--
-- 複数のオブジェクトをまとめて一つのオペランドに流し込む
--
dev.sum = dev.new_class(
{
	__init = function(self, args)
		if args.relation then
			self.rel = args.relation
		else
			self.rel = dev.independent()
		end
		
		self.priority = dev.option_arg(args.priority, {})
		self.parameter = dev.option_arg(args.parameter, {})
		
		self.objects = {}
		for i, o in ipairs(args) do
			self.objects[i] = o
			if self.priority[i]==nil then
				self.priority[i]=i
			end
		end
	end,
	
	-- インターフェース関数	
	--
	Exists = function( self, est )
		return self.rel:DoExists( est, self.priority, self )
	end,
	
	Select = function( self, est )
		local sels = self.rel:DoSelect( est, self.priority, self )
		for _, i in ipairs(self.parameter) do
			sels[i] = nil
		end		
		return dev.Group.FlatGroups(sels)
	end,
	
	GetMinMax = function( self, est )
		local mi, mx=0, 0
		for i, o in ipairs(self.objects) do
			local mmi, mmx = o:GetMinMax(est)
			mi = mi + mmi
			mx = mx + mmx
		end
		return mi, mx
	end,
	
	--
	nextElem = function( self, est, i )
		est:ResetOperandState()
		return self.objects[i]
	end,
	countElem = function( self )
		return #self.objects
	end,
})

--
-- オブジェクトそれぞれが別のオペランドである
--
dev.operands = dev.new_class(dev.sum,
{
	__init = function( self, args )
		dev.super_init( self, args )
		
		if args.relation then
			self.rel = args.relation
		else
			self.rel = dev.fulfill{ function(est,...) return est:IsOperable(...) end }
		end
	end,
	
	-- インターフェース関数
	--
	Exists = function( self, est )
		return self.rel:DoExists( est, self.priority, self )
	end,
	
	Select = function( self, est )
		local sels = self.rel:DoSelect( est, self.priority, self )
		return dev.operand_container( sels )
	end,
	
	GetMinMax = function( self, est )
		local opi=est:CurOpState().cur_operand
		local o=self.objects[opi]
		if o then return o:GetMinMax(est) end
	end,
	
	GetAll = function( self, est )
		local opi=est:CurOpState().cur_operand
		local o=self.objects[opi]
		if o then return o:GetAll(est) end
	end,
	
	-- メンバ関数
	--
	nextElem = function( self, est, i )
		est:CurOpState(i):setCurOperand(i)
		est:ResetOperandState()
		return self.objects[i]
	end,
	countElem = function( self )
		return #self.objects
	end,
})

--
dev.operand_container = dev.new_class(
{
	__init = function( self, val )
		self.opr = dev.option_arg( val, {} )
	end,
	Format = function( self, val )
		if dev.is_class( val, self ) then
			self.opr = val.opr
		elseif type(val) == "table" and not dev.is_class( val ) then
			self.opr = val
		else
			self.opr = { val }
		end
	end,
	GetTable = function( self )
		return self.opr
	end,
	OperandAt = function( self, i )
		return self.opr[i]
	end,
	Empty = function( self )
		return #self.opr==0 
	end,
})

--
--
-- objects / operandで使う relation
--
-- 
dev.independent = dev.new_class(
{
	DoExists = function( self, est, priority, parent )
		est:SaveOperandState()
	
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem( est, i )
			if not o:Exists( est ) then
				return false
			end
		end
		return true
	end,

	DoSelect = function( self, est, priority, parent )
		est:SaveOperandState()
		
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem( est, i )
			stack[i]=o:Select( est )
		end
		return stack
	end,
})


--
dev.fulfill = dev.new_class(
{
	__init = function(self, arg)
		if type(arg)=="function" then
			self.unexp = {}
			self.rel = arg
		else
			self.unexp = dev.table.make_value_dict( dev.option_arg(arg.unexpand,{}) )
			self.rel = arg[1]
		end
	end,
	
	--
	CheckRelation = function( self, est, parent, stack, topidx )
		local order = self:genDepthOrder( topidx, parent:countElem() )
		
		
		local idx=order[1]
		if self.unexp[idx] then
			local args = {}
			self:chkRelStep( 1, parent, stack, order, args, est )
			return stack[idx]
		else
			local o=parent:nextElem(est, idx)
			local g=o:GetAll( est )
			stack[idx]=g
			
			return g:Filter(function(c) 
				local args = { [idx] = c }
				return self:chkRelStep( 2, parent, stack, order, args, est )
			end, nil )
		end
	end,
	
	chkRelStep = function( self, i, parent, stack, order, args, est )
		local ni=i+1
		local idx=order[i]
		
		local gsel=stack[idx]
		if gsel==nil then
			local o=parent:nextElem(est, idx)
			gsel=o:GetAll( est )
			stack[idx]=gsel
		end
		
		local unexp = self.unexp[idx]
		
		local tc=gsel:GetFirst()
		while tc do
			if unexp then
				args[idx] = gsel
			else
				args[idx] = tc
			end
			
			-- 次の階層へ
			if order[ni]==nil then
				local b=self.rel(est, table.unpack(args))
				if b then
					return true
				end
			elseif self:chkRelStep( ni, parent, stack, order, args, est ) then
				return true
			end
			
			if unexp then -- 失敗
				break
			else
				tc=gsel:GetNext()
			end
		end
		return false
	end,
	
	genDepthOrder = function( self, i, cnt )
		local preset = self.DepthOrderPresets[cnt]
		if preset ~= nil then
			return preset[i]
		else
			local tbl={i}
			for j=1,cnt do
				if j~=i then table.insert(tbl, j) end
			end
			return tbl
		end
	end,
	
	DepthOrderPresets = {
		[1]={{1}},
		[2]={{1,2}, {2,1}},
		[3]={{1,2,3}, {2,1,3}, {3,1,2}},
	},
	
	-- インターフェース関数
	--
	DoExists = function( self, est, priority, parent )
		est:SaveOperandState()
		
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem( est, i )
			if not o:Exists( est ) then -- pieをチェックするために呼び出す
				dev.print("failed:", i)
				return false
			end
			local mi, mx=o:GetMinMax( est )
			
			 -- CheckRelation内でカレントのオペランドが変更される
			local gsel=self:CheckRelation( est, parent, stack, i )
			
			--dev.print(g:GetCount(), "/", gsel:GetCount(), "/", mi, "-", mx)
			if not gsel or gsel:GetCount() < mi then
				return false
			end			
			stack[i] = gsel
		end
		return true
	end,

	--
	DoSelect = function( self, est, priority, parent )
		est:SaveOperandState()
		
		local stack = {}
		for _, i in ipairs(priority) do
			est:ResetOperandState()
			local g=self:CheckRelation( est, parent, stack, i )
			if g:GetCount()==0 then
				return {}
			end
			
			local o=parent:nextElem( est, i ) -- CheckRelation内でカレントのオペランドが変更される
			est:OperandState().source = g
			local gsel=o:Select( est )
			stack[i] = gsel
		end
		return stack
	end,
})

--
-- オペレーションの引数
--
dev.op_operand = dev.new_class(
{
	__init = function( self, op, operand )
		self.op = op
		self.opr = dev.option_arg(operand, 1)
	end,
	
	getOpValue = function( self, est, req )
		local r=est:GetOpOperand( self.op, self.opr )
		if req and r==nil then
			est:OpDebugDisp("op_operand: キー=", self.op.key, "のオペレーションはまだ実行されていません")
		end
		return r
	end,
	
	-- インターフェース関数
	Select = function( self, est )
		return self:getOpValue(est, true)
	end,
	Exists = function( self, est )
		local r=est:GetOpCheck( self.op )
		return r
	end,
	GetAll = function( self, est )
		local r=self:getOpValue(est)
		if r then
			return r
		else
			return self.op:GetAllOperand( est, self.opr )
		end
	end,	
	GetMinMax = function( self, est )
		local mi = 0
		local mx = 0
		local r=self:getOpValue(est)
		if r then
			mi = r:GetCount()
			mx = mi
		else
			mi, mx=self.op:GetMinMaxOperand( est, self.opr )
		end
		return mi, mx
	end,
	Location = function( self, est )
		return self.op:LocationOperand( est, self.opr )
	end,
})

--
-- オペレーションの結果
--
dev.op_operated = dev.new_class(dev.op_operand,
{
	__init = function( self, op, operand )
		dev.super_init( self, op, operand )
	end,
	
	getOpValue = function( self, est, req )
		local r=est:GetOpOperated( self.op, self.opr )
		if req and r==nil then
			est:OpDebugDisp("op_operated: キー=", self.op.key, "のオペレーションはまだ実行されていません")
		end
		return r
	end,
})


--
--
-- フィルター
--
--

-- 先頭にestを置けるフィルタ関数を生成
dev.head_est_object_filter = dev.new_class(
{	
	__init = function( self, f )
		self:Set( f )
	end,
	
	-- フィルターを設定
	Set = function( self, basefilter )
		self.basefilter = basefilter
		self.filter = function( est, o )
			if self.basefilter==nil or self.basefilter( est, o ) then
				return est:IsOperableSep(o)
			end
			return false
		end
	end,
	
	SetRaw = function( self, f )
		self.basefilter = f
		self.filter = f
	end,
	
	Get = function( self )
		return self.filter
	end,
	
	Invoke = function( self, ... )
		return self.filter( ... )
	end,
})

-- 末尾にestを置けるフィルタ関数を生成
dev.tail_est_object_filter = dev.new_class(dev.head_est_object_filter,
{
	__init = function( self, f )
		dev.super_init( self, f )
	end,
	
	-- フィルターを設定
	Set = function( self, basefilter )
		self.basefilter = basefilter
		self.filter = function( o, est )
			if self.basefilter==nil or self.basefilter( o, est ) then
				return est:IsOperableSep(o)
			end
			return false
		end
	end,
})


-- 
-- ================================================================================
--
--  アクション
--
-- ================================================================================
-- オペランド・返り値を登録するだけ
dev.do_let = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, 0, 0, nil )
		self.fn = dev.option_field( args, 1 )
	end,
	
	Execute = function( self, est, ... )
		local st = est:CurOpState()
		if st then
			local r 
			if self.fn then
				r = { self.fn( ... ) }
			else
				r = { ... }
			end
			st:setOperated( r )
		end
		return 1
	end,
})

-- 任意のカスタマイズが可能
dev.do_action = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, args.cat, args.hint, args.arity )
	
		self.check = args.check
		if self.check==nil then
			self.check=function(...) return true end
		end
		self.checksep = args.checksep
		if self.checksep==nil then
			self.checksep=self.check
		end
		self.execute = args.execute
	end,
	CheckOperable = function( self, est, ... )
		return self.check( est, ... )
	end,
	CheckOperableSep = function( self, est, o, idx )
		if self.arity==1 then
			return self:CheckOperable( est, o )
		elseif self.arity>1 then
			return self.checksep( est, o, idx )
		end
	end,
	Execute = function( self, est, ... )
		if self.execute then return self.execute( est, ... ) end
		return 1
	end,
})
