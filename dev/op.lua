--
-- ================================================================================
--
-- オペレーション = アクション + オペランド（オブジェクトを入れるとこ）
-- 
-- ================================================================================
--
-- Check
-- Execute
-- ExecuteAction
-- GetHint
--
for _, k in ipairs({"Select", "Exists", "Count", "GetMinMax", "Location", "GetAll"}) do
	dev[k.."Operand"] = function( o, est, operand_args, op_state )
		local f=o[k]
		est:pushOpStackFrame( op_state, operand_args )
		local r=f( o, est )
		est:popOpStackFrame()
		return r
	end
end


--
-- カードを操作する
-- dev.op{ action, operand, debug="aaa" }
--
dev.op = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		self.action = args[1]
		self.operand = args[2]
		self.flags = 0
		self._dbgmode = args.debug -- 文字列を入れるとデバッグ表示
		
		dev.table.addmeta( self, { __call = function(self, ...) return self:Execute(...) end } )
	end,
	
	--
	-- estに自身を積む
	-- 
	beginOp = function( self, est, opdidx, oprst )
		if self.key==nil then
			dev.print("オペレーションに識別IDがありません AddOperationの使用漏れを確認してください")
			return nil
		end	
		local ops = est:newOpState( self.key, self )
		if opdidx then
			ops:setCurOperand( opdidx )
		end
		est:pushOpStackFrame( ops, oprst )
		return ops
	end,
	exitOp = function( self, est, r )
		est:popOpStackFrame()
		return r
	end,
	
	--
	-- インターフェース関数
	--
	-- Check
	Check = function( self, est, oprst )
		local opst = self:beginOp( est, 1, oprst )
		
		local ret=false
		if not self:chkOperand( est, opst ) then
			self:DebugDisp( est, "Check failed: オペランド" )
		elseif self.action.Check~=nil and self.action:Check( est ) then
			self:DebugDisp( est, "Check failed: action.Check" )
		else
			self:DebugDisp( est, "Check Ok" )
			ret=true
		end
		
		opst:setCheckResult( ret )
		return ret, self:exitOp(est)
	end,
	
	-- Execute
	-- 	ocs : {[1]:grp, [2]:grp}
	Execute = function( self, est, oprst )
		return self:ExecuteAction( est, oprst )
	end,
	
	--
	ExecuteAction = function( self, est, oprst )
		local opst = self:beginOp( est, 1, oprst )
		
		-- 対象決定
		local operands=self:selOperand( est, opst ) 
		
		-- 動作実行
		local ops = operands:GetTable()
		if self:IsDebug() then
			for i, o in ipairs(ops) do
				if o==nil then
					self:DebugDisp( est, "オペランド[", i, "]がnilです" )
				end
			end
		end
		local cnt = self.action:Execute( est, table.unpack(ops) )
		
		-- 結果保存
		opst:setOperatedCount( cnt )
		if opst.operated==nil then
			local g=Duel.GetOperatedGroup()
			opst:setOperated{g}
		end
		
		self:DebugDisp( est, "Execute完了: cards=", opst:GetOperatedCount() )
		self:exitOp(est)
		return opst
	end,
	
	-- ヒントコード
	GetHint = function( self )
		return self.action.hint
	end,
	
	-- 
	-- 内部メンバ関数(pushSelfしてる前提)
	--
	-- 動作に適合するカードか
	chkOperableObject = function( self, est, ... )
		return self.action:CheckOperable( est, ... )
	end,
	
	chkOperableObjectSep = function( self, est, obj, operand )
		if not self.action:CheckOperableSep( est, obj, operand ) then
			self:DebugDisp( est, "op.CheckOperableSep Failed: operand=", operand )
			return false
		end
		return true
	end,
	
	-- オペランドがそろっているか確認
	chkOperand = function( self, est )
		if self.operand==nil then return true end
		return self.operand:Exists( est )
	end,
	
	-- 操作対象となるカードを選ぶ
	selOperand = function( self, est, opst )
		local opc=dev.operand_container()
		if self.operand~=nil then
			local ret=self.operand:Select( est )
			debug.sethook()
			if ret==nil then 
				self:DebugDisp( est, "操作対象の取得に失敗" )
			end
			opc:Format( ret )
		end
		opst:setOperand( opc )
		return opc
	end,
	
	-- 
	-- その他のメンバ関数
	--
	-- cnt, cnt / min, max を返す
	GetMinMaxOperand = function( self, est, opdidx, oprst )
		local opst = self:beginOp( est, opdidx, oprst )
		local c1, c2 = 0, 0
		if self.operand then
			if self.operand.GetMinMax then
				c1, c2 = self.operand:GetMinMax(est)
			elseif self.operand.Count then
				c1 = self.operand:Count(est)
				c2 = c1
			end
		end
		self:exitOp( est )
		return c1, c2
	end,
	
	-- オブジェクトの領域をまとめて返す
	LocationOperand = function( self, est, opdidx, oprst )
		local opst = self:beginOp( est, opdidx, oprst )
		if self.operand==nil then return dev.location_info() end
		return self:exitOp( est, self.operand:Location(est) )
	end,
	
	-- 操作対象となるカードをすべて取得
	GetAllOperand = function( self, est, opdidx, oprst )
		local opst = self:beginOp( est, opdidx, oprst )
		return self:exitOp( est, self.operand:GetAll(est) )
	end,
	
	-- フラグ
	AddFlag = function( self, flags )
		self.flags = bit.bor( self.flags, flags )
	end,
	TestFlag = function( self, f )
		return bit.btest( self.flags, f )
	end,
	
	--
	-- デバッグ関数
	--	
	-- 表示
	DebugDisp = function(self, est, ...)
		if self:IsDebug() then		
			local sig="this=["..self._dbgmode
			sig=sig.." "..dev.cardstr(est:GetHandler())
			sig=sig.."] "
			dev.print(sig, ...)
		end
	end,
	
	-- デバッグ表示をオンにする
	Debug = function(self, s) -- s:識別用の文字列
		if s==nil then
			self._dbgmode="Cat="..tostring(self.category)
		else
			self._dbgmode=s
		end
	end,
	
	IsDebug = function(self)
		return self._dbgmode~=nil
	end,
}) 

--
--
--  条件 - Checkに関してはdev.opと同様に扱える
--
--
-- オブジェクトの数を調べる
dev.count_operand = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		self.oargs = {}
		for k, a in pairs(args) do
			local i=tonumber(k)
			if i==1 then
				self.o = a
			else
				self.oargs[k] = a
			end
		end
	end,
	
	-- Check
	Eval = function( self, est )
		return dev.CountOperand( self.o, est, self.oargs )
	end,
})

-- 指定数以上存在する
dev.cond_exist = dev.new_class(dev.count_operand,
{
	__init = function( self, args )
		dev.super_init( self, args )
	end,

	-- Check
	Eval = function( self, est )
		return dev.ExistsOperand( self.o, est, self.oargs )
	end,
})

-- 存在しない
dev.cond_none_exist = dev.new_class(dev.count_operand,
{
	__init = function( self, args )
		dev.super_init( self, args )
	end,

	-- Check
	Eval = function( self, est )
		return not dev.ExistsOperand( self.o, est, self.oargs )
	end,
})

-- 
-- ================================================================================
--
--  オブジェクト - ある操作の対象となる何か（カード、ライフ、チェーンなど）
--
-- ================================================================================
--
-- : Exists
-- : Select
-- : GetAll
-- : GetMinMax
-- : Location
--
dev.primal_object = dev.new_class(
{
	-- メンバ関数	
	GetAll = function(self, est)
		local gsrc=self:getOutSource(est)
		if gsrc then
			return gsrc
		else
			return self:GetAllObject( est )
		end
	end,
	
	Count = function(self, est)
		local gsrc=self:getOutSource(est)
		if gsrc then
			return gsrc:GetCount()
		else
			return self:CountObject( est )
		end
	end,
	
	GetMinMax = function(self, est)
		return 1, self:Count(est)
	end,
	
	Exists = function( self, est )
		local reqnum = dev.option_arg(est:OperandState().min, 1)
		local gsrc=self:getOutSource(est)
		if gsrc then
			return reqnum <= gsrc:GetCount()
		else
			return self:ExistsObject( est, reqnum )
		end
	end,
	
	Select = function( self, est )
		return self:GetAll(est)
	end,
	
	SelectImpl = function( self, est )
		local tp = est:OperandState().select_player
		
		local selmax = est:OperandState().max
		if selmax==nil then selmax=self:Count(est) end
		
		local selmin = est:OperandState().min
		if selmin==nil then selmin=1 end
		
		local gsrc=self:getOutSource(est)
		return self:SelectImplObject( est, tp, selmin, selmax, gsrc )
	end,
	
	Location = function(self, est)
		return dev.location_info()
	end,
	
	Match = function(self, c, est)
		local f = self:GetFilter(est)
		return f(c, est)
	end,
	
	--
	getOutSource = function(self, est)
		local gsrc=est:OperandState().source
		if gsrc then
			gsrc=gsrc:Filter( self:GetFilter(est), self:GetException(est), est )
			return gsrc
		end
		return nil
	end,
})

--
-- =====================================================================
--
--  アクション - 破壊する、サーチする、失う、無効にするなどの操作
--
-- =====================================================================
--
-- CheckOperable		( self, est, c, operand-id ) -> boolean
-- Execute				( self, est, operand1, operand2... ) -> operated_count, [opt]another_operation_result
-- DoCheck				[opt] ( self, est )
-- OperationInfoParams	[opt] ( self, est ) -> Param, Player
--

-- action 基底クラス
dev.action = dev.new_class(
{
	__init = function( self, cat, hint, arity )
		self.category 	 = cat
		self.hint 		 = hint
		self.arity 		 = dev.option_arg(arity,1)
		self.act_category = cat
	end,
	CheckOperable = function(self, est) 
		return true
	end,
	CheckOperableSep = function(self, est, o, opr)
		if self.arity==1 then
			return self:CheckOperable(est, o)
		elseif self.arity>1 then
			return true
		end
	end,
	
	--
	FillActivationInfo = function( self, est, ent, op, opindex )
		local opr=est:GetOpOperand( op, opindex )
		if opr then
			if ent.cards==nil then
				ent.cards = opr
			end
			if ent.count==nil then
				ent.count = opr:GetCount()
			end
		else
			if ent.cards==true then
				local og = op:GetAllOperand( est, opindex )
				ent.cards = og
			end
			if ent.count==nil then
				local mi, mx = op:GetMinMaxOperand( est, opindex )
				ent.count = mi
			end
			if ent.location==true then
				local l = op:LocationOperand( est, opindex )
				ent.value = l
			end
		end
	end,
})

