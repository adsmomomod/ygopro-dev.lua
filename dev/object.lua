--
--
--
dev.nil_object_c = dev.new_class(
{
	Exists = function()
		return true
	end,
	
	Select = function()
		return nil
	end,
	
	GetAll = function()
		return Group.CreateGroup()
	end,	
})
dev.nil_object = dev.nil_object_c()

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
--  !! 二次オブジェクト
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
		self.o = args.from
		self.selmin = dev.option_arg( args.min, args.count )
		self.selmax = dev.option_arg( args.max, args.count )
		self.select_player = dev.option_arg( args.player, dev.you )
		self.customhint = args.hint
		self.pie = args.pie
		self.hintsel = args.hintsel
		
		dev.require( args, {{ from = true }} )
		dev.require( self.selmin, dev.eval_able("number") )
		dev.require( self.selmax, dev.eval_able("number") )
	end,
	
	-- インターフェース関数
	Exists = function( self, est, istarget )
		local mi, mx = self:GetMinMax( est )
		if not self.o:Exists( est, istarget, mi ) then
			return false
		end
		
		if self.pie then self.pie:Update( est, mi ) end
		return true
	end,
	
	-- ヒント表示、選択
	Select = function( self, est, istarget, gsel )
		local sp=self.select_player:GetPlayer(est)
		self:HintSelect( est, sp )
		
		local mi, mx = self:GetMinMax( est )
		local g
		if self.o.SelectImpl then
			g=self.o:SelectImpl( est, istarget, sp, mi, mx, gsel )
		elseif not istarget then
			g=self.o:Select( est, istarget ) -- 取り出して
			g=g:Select( sp, mi, mx, nil )	 -- その中から選ぶ
		elseif istarget then
			dev.print(" 対象をとる効果の場合はselの代わりにtarget_selをお使いください ")
		end
		
		if self.hintsel then
			Duel.HintSelection( g ) -- g
		end
		
		if self.pie then self.pie:Update( est, g:GetCount() ) end
		return g
	end,
	
	GetAll = function( self, est, istarget )
		return self.o:GetAll( est, istarget )
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
	
	Reselect = function( self, est, gsel, selcnt )
		local sp=self.select_player:GetPlayer(est)
		self:HintSelect( est, sp, true )
		return self.o:Select( est, false, sp, selcnt, selcnt, gsel )
	end,
	
	-- メンバ関数
	HintSelect = function( self, est, tp )
		local ophint = nil
		if est:HasOpState() then ophint = est:TopOp():GetHint() end
		
		if self.customhint~=nil then
			self.customhint( tp, ophint )
		else
			Duel.Hint( HINT_SELECTMSG, tp, ophint )
		end
	end,
})

--
-- 上限を超えていた場合のみ選択する
--
dev.lim_sel = dev.new_class(dev.sel,
{
	

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
		local sp=self.select_player:GetPlayer( est )
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
		local selp=self.select_player:GetPlayer(est)
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
	Select = function( self, est, istarget )
		local sp=self.select_player:GetPlayer(est)
		self:HintSelect( est, sp )
		
		local gall=self.o:GetAll( est, istarget )
		
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
-- オブジェクトをまとめて一つのオペランドに流し込む
--
dev.object_set = dev.new_class(
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
	Exists = function( self, est, istarget )
		return self.rel:DoExists( est, istarget, self.priority, self )
	end,
	
	Select = function( self, est, istarget )
		local sels = self.rel:DoSelect( est, istarget, self.priority, self )
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
	
	Reselect = function( self, est, gsel, selcnt )
		-- 先頭オブジェクトのReselectを使用する
		return self.objects[1]:Reselect( est, gsel, selcnt )
	end,
	
	--
	nextElem = function( self, est, i )
		return self.objects[i]
	end,
	countElem = function( self )
		return #self.objects
	end,
})

--
-- オブジェクトそれぞれが別のオペランドである
--
dev.operands = dev.new_class(dev.object_set,
{
	__init = function( self, args )
		dev.super_init( self, args )
		
		if args.relation then
			self.rel = args.relation
		else
			self.rel = dev.each_related(dev.IsOperable)
		end
	end,
	
	-- インターフェース関数
	--
	Exists = function( self, est, istarget )
		return self.rel:DoExists( est, istarget, self.priority, self )
	end,
	
	Select = function( self, est, istarget )
		local sels = self.rel:DoSelect( est, istarget, self.priority, self )
		return dev.operand_container( sels )
	end,
	
	GetMinMax = function( self, est, operand_index )
		local o=self.objects[operand_index]
		if o then return o:GetMinMax(est) end
	end,
	
	GetAll = function( self, est, operand_index )
		local o=self.objects[operand_index]
		if o then return o:GetAll(est) end
	end,
	
	-- メンバ関数
	--
	nextElem = function( self, est, i )
		est:TopOpState():setCurOperand(i)
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
})

--
--
-- objects / operandで使う relation
--
-- 
dev.independent = dev.new_class(
{
	DoExists = function( self, est, istarget, priority, parent )
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem( est, i )
			if not o:Exists( est, istarget ) then
				return false
			end
		end
		return true
	end,

	DoSelect = function( self, est, istarget, priority, parent )
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem( est, i )
			stack[i]=o:Select( est )
		end
		return stack
	end,
})


--
dev.each_related = dev.new_class(
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
	CheckRelation = function( self, est, istarget, parent, stack, topidx )
		local order = self:genDepthOrder( topidx, parent:countElem() )
		
		local args = {}
		
		local idx=order[1]
		if self.unexp[idx] then
			self:checkRelation( 1, parent, stack, order, args, est, istarget )
			return stack[idx]
		else
			local o=parent:nextElem(est, idx)
			local g=o:GetAll(est, istarget)
			stack[idx]=g
			
			return g:Filter( function( c, a ) 
				a[idx] = c
				return self:checkRelation( 2, parent, stack, order, a, est, istarget )
			end, nil, args )
		end
	end,
	
	checkRelation = function( self, i, parent, stack, order, args, est, istarget, retargs )
		local ni=i+1
		local idx=order[i]
		--dev.print_table(stack, "stack-"..tostring(i))
		--dev.print_table(args, "args-"..tostring(i))
		--dev.print("cur objindex=",tostring(idx))
		--dev.print("----------------------------")
		
		local gsel=stack[idx]
		if gsel==nil then
			local o=parent:nextElem(est, idx)
			gsel=o:GetAll(est, istarget)
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
				--dev.print_val("pre-rel ", idx, self.unexp[idx], args[1], args[2], args[3], args[4])
				local b=self.rel(est, table.unpack(args))
				--dev.print("Try: ",dev.option_val(b,"Ok","Fail"),", ", dev.typestr(args[1]), ", ", dev.typestr(args[2]))
				if b then
					return true
				end
			elseif self:checkRelation( ni, parent, stack, order, args, est, istarget ) then
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
	DoExists = function( self, est, istarget, priority, parent )
		local stack = {}
		for _, i in ipairs(priority) do
			local o=parent:nextElem(est, i)
			if not o:Exists(est, istarget) then -- pieをチェックするために呼び出す
				dev.print("failed:", i)
				return false
			end
			local mi, mx=o:GetMinMax(est) 
			
			 -- CheckRelation内でカレントのオペランドが変更される
			local gsel=self:CheckRelation( est, istarget, parent, stack, i )
			
			--dev.print(g:GetCount(), "/", gsel:GetCount(), "/", mi, "-", mx)
			
			if not gsel or gsel:GetCount() < mi then
				return false
			end			
			stack[i] = gsel
		end
		return true
	end,

	--
	DoSelect = function( self, est, istarget, priority, parent )
		local stack = {}
		for _, i in ipairs(priority) do
			local g=self:CheckRelation( est, istarget, parent, stack, i )
			if not g then
				return {}
			end
			
			local o=parent:nextElem(est, i) -- CheckRelation内でカレントのオペランドが変更される
			local gsel=o:Select( est, istarget, g )			
			stack[i] = gsel
		end
		return stack
	end,
})

--
-- オペレーションの結果
--
dev.operation_result = dev.new_class(
{
	__init = function( self, op, operand )
		self.op = op
		self.opr = dev.option_arg(operand, 1)
	end,
	
	-- インターフェース関数
	Select = function( self, est )
		local r=est:GetOpResult( self.op )
		if r==nil then
			est:OpDebugDisp("operation_result: キー=", self.op.key, "のオペレーションはまだ実行されていません")
		end
		return r:GetOperand( self.opr )
	end,
	Exists = function( self, est )
		local r=est:GetOpCheck( self.op )
		return r
	end,
	GetAll = function( self, est )
		local r=est:GetOpResult( self.op )
		if r~=nil then
			return self:Select( est )
		else
			local r=est:InvokeOp( self.op, function(o, es) 
				return o:GetAllObject( est, self.opr ) 
			end)
			return r[1]
		end
	end,	
	GetMinMax = function( self, est )
		local mi = 0
		local mx = 0
		local r=est:GetOpResult( self.op )
		if r~=nil then
			mi = self:Select( est ):GetCount()
			mx = mi
		else
			mi, mx=est:InvokeOp( self.op, function(o, es) 
				return o:GetObjectMinMax( est, self.opr ) 
			end)
		end
		return mi, mx
	end,
	Location = function( self, est )
		return self.op:GetObjectLocation( est, self.opr )
	end,
})


--
-- 効果対象となるオブジェクト
--
dev.target_sel = dev.new_class(
{
	__init = function(self, a1, a2)
		if a2==nil then
			self.index = 1
			self.base = a1
		else 
			self.index = a1
			self.base = a2
		end

		if not dev.is_class(self.base) then
			local cls=dev.option_arg(self.base.class, dev.sel)
			self.base=cls(self.base)
		end
	end,

	-- インターフェース関数
	Select = function( self, est, _istarget, gsel ) -- このSelectは対象決定時と効果解決時の２度呼ばれる
		local tg=nil
		if est.timing == dev.ontarget then
			tg=self.base:Select( est, true, gsel )
			est:GetEffectClass():TellTargetPart( est, self.index, tg )
			
		elseif est.timing == dev.onoperation then	
			tg=est:GetTarget( self.index )
			if tg==nil then
				est:OpDebugDisp("Failed effect_state.GetTarget")
				return nil
			end
			
			-- 必要ならReselect
			local mi, mx = self.base:GetMinMax( est )
			if mx<tg:GetCount() then
				tg=self.base:Reselect( est, tg, mx )
			end
		end
		return tg
	end,
	
	Exists = function( self, est )
		return self.base:Exists( est, true )
	end,
	
	GetAll = function( self, est )
		return self.base:GetAll( est, true )
	end,	
	
	GetMinMax = function( self, est )
		return self.base:GetMinMax( est )
	end,
	
	Location = function( self, est )
		return self.base:Location( est )
	end,
})
