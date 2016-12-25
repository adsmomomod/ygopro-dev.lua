--
-- ハンドラに渡される引数、オペレーションの状態、対象カードなど、あらゆる変化する情報を収める
--
dev.effect_state = dev.new_class(
{
	__init = function( self, ec, tim ) 
		self.eclass = ec
		self.timing = tim
		
		self.tg = nil
		
		self.opst = {}
		self.opstack = {}
		self.pie_counters = {}
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
	IsRelateToEffect = function(self, c)
		return c:IsRelateToEffect(self:GetEffect())
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
	-- オペレーションの状態
	--
	-- 新しいオペレーションを登録
	newOpState = function( self, key, op )
		if self.opst[key]==nil then
			self.opst[key]=dev.operation_state( op )
		end
		return self.opst[key]
	end,
	
	CurOpState = function(self)
		local sf=self:curOpStackFrame()
		if sf then return sf.state end
	end,
	CurOp = function(self)
		local sf=self:curOpStackFrame()
		if sf and sf.state then return sf.state.op end
	end,
	
	GetOpState = function( self, op )
		return self.opst[op.key]
	end,
	GetOpCheck = function( self, op )
		return self.opst[op.key].check
	end,
	GetOpResult = function( self, op )
		return self.opst[op.key].result
	end,
	GetOpOperand = function( self, op, opr )
		local r=self:GetOpState(op)
		if r then return r:GetOperand(opr) end
		return nil
	end,
	GetOpOperated = function( self, op, opr )
		local r=self:GetOpState(op)
		if r then return r:GetOperated(opr) end
		return nil
	end,
	
	--
	-- オペレーション実行時のスタック
	--
	pushOpStackFrame = function( self, operation_st, operand_st )
		local stack = dev.operation_stack_frame( self, operation_st, operand_st )
		table.insert( self.opstack, stack )
	end,
	popOpStackFrame = function( self )
		self.opstack[#self.opstack] = nil
	end,
	curOpStackFrame = function( self )
		return self.opstack[#self.opstack]
	end,
	
	-- オペレーション実行時の任意の変数
	OperationArg = function( self )
		return self:curOpStackFrame().args
	end,
	
	-- オペランドに渡す任意の変数
	OperandState = function( self )
		local t=self:curOpStackFrame()
		if t==nil then dev.print_locals() end
		return t.operand_state
	end,
	SaveOperandState = function( self )
		local t=self:curOpStackFrame()
		t.saved_operand_state = dev.table.shallowcopy(t.operand_state)
	end,
	ResetOperandState = function( self )
		local t=self:curOpStackFrame()
		t.operand_state = dev.table.shallowcopy(t.saved_operand_state)
	end,
	
	-- カウンター
	GetPieCounter = function( self, key )
		local pi=self.pie_counters[key]
		if pi==nil then
			self:OpDebugDisp("key=",key,"のパイカウンターが作成されていません")
		end
		return pi
	end,
	ResetPieCounters = function( self )
		local pies = self.eclass:GetPies()
		for i, pie in ipairs( pies ) do
			local ni = dev.pie_counter( pie )
			ni:Reset( self )
			self.pie_counters[pie.key] = ni 
		end
	end,
	CheckPieCounters = function( self )
		for k, picnt in pairs( self.pie_counters ) do
			if not picnt:Check( self ) then
				return false
			end
		end
		return true
	end,
	
	-- 対象 
	GetActivationTarget = function(self, idx)
		return self.tg[idx]
	end,
	setActivationTarget = function(self, tgs)
		self.tg=tgs
	end,
	
	--
	-- 現在のオペレーションに合うオブジェクトかを調べる
	--
	IsOperable = function( self, ... )
		local op=self:CurOp()
		if op then
			return op:chkOperableObject( self, ... )
		end
		return true
	end,
	
	IsOperableSep = function( self, o )
		local opst=self:CurOpState()
		if opst and opst.op then
			return opst.op:chkOperableObjectSep( self, o, opst.cur_operand )
		end
		return true
	end,
	
	-- デバッグ関数
	OpDebugDisp = function(self, ...)
		local sf=self:curOpStackFrame()
		if sf then
			sf.state.op:DebugDisp(self, ...)
		end
	end
})

-- 
dev.operation_stack_frame = dev.new_class(
{
	__init = function( self, est, state, opr_args )
		self.state = state
		self.args  = dev.option_arg( opr_args, {} )
		self.operand_state = {}
		self.saved_operand_state = {}
	end,
})

-- 
dev.operation_state = dev.new_class(
{
	__init = function(self, op)
		self.op = op
		self.cur_operand = 1
		self.check = false
		--self.operand = nil
		--self.operated = nil
		--self.operated_count = nil
		--self.result = nil
	end,
	
	-- 
	setCurOperand = function( self, opr )
		self.cur_operand = opr
	end,
	setCheckResult = function( self, r )
		self.check = r
	end,
	setOperand = function( self, opr ) -- operand_container
		self.operand = opr
	end,
	setOperated = function( self, opr ) -- table
		self.operated = opr
	end,
	setOperatedCount = function( self, c )
		self.operated_count = c
	end,
	setResult = function( self, r )
		self.result = r
	end,
	
	-- 
	GetOperand = function( self, i )
		return self.operand:GetTable()[ dev.option_arg(i,1) ]
	end,
	GetOperated = function( self, i )
		return self.operated[ dev.option_arg(i,1) ]
	end,
	GetOperatedCount = function( self )
		return self.operated_count
	end,
	GetResult = function( self )
		return self.result
	end,
	Done = function( self, val )
		if val then return self.operated_count>=val
		else return self.operated_count>0 end
	end,
})
