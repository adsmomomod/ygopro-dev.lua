--
-- ===============================================================================-
--
-- !! オペレーション
-- 
-- ===============================================================================
--
-- check_timing
-- Check
-- Target
-- Execute
-- IsTakeTarget
-- GetHint
-- DebugDisp
--

-- カードを操作する
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
	-- インターフェース関数
	--
	-- Check
	Check = function( self, est )
		local opst=self:pushSelf(est)
		local ret=false
		
		if not self:chkOperand( est ) then
			self:DebugDisp( est, "Check failed: オペランド" )
		elseif self.action.Check~=nil and self.action:Check(est) then
			self:DebugDisp( est, "Check failed: action.Check" )
		else
			self:DebugDisp( est, "Check Ok" )
			ret=true
		end
		
		opst:setCheckResult( ret )
		return ret
	end,
	
	-- Execute
	-- 	ocs : {[1]:grp, [2]:grp}
	Execute = function( self, est, ocs )
		return self:ExecuteAction( est, ocs )
	end,
	
	--
	ExecuteAction = function( self, est, ocs )
		local opst = self:pushSelf( est )
		
		-- 対象決定
		local operands=self:selOperand( est, ocs ) 
		
		-- 動作実行
		local ops = operands:GetTable()
		if self:IsDebug() then
			for i, o in ipairs(ops) do
				if o==nil then
					self:DebugDisp( est, "オペランド[", i, "]がnilです" )
				end
			end
		end
		local cnt, other = self.action:Execute( est, table.unpack(ops) )
		
		-- 結果保存
		local ret = dev.op_result( cnt, operands, other )
		opst:setResult( ret )
		self:DebugDisp( est, "Execute完了: cards=", ret.count, " ret=", dev.valstr(ret.value) )
		return ret
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
		if not self.action.CheckOperableSep( est, obj, operand ) then
			self:DebugDisp( est, "op.CheckOperableSep Failed: operand=", operand )
			return false
		end
		return true
	end,
	
	-- Check:カスタムポイント オペランドがそろっているか確認
	chkOperand = function( self, est )
		if self.operand==nil then return true end
		return self.operand:Exists( est )
	end,
	
	-- 操作対象となるカードを選ぶ
	selOperand = function( self, est, ocs )
		if ocs~=nil then
			if type(ocs)~="table" then ocs={ocs} end
			est:TopOpState():SetArgument( ocs )
		end	

		local opc=dev.operand_container()
		if self.operand~=nil then
			local ret=self.operand:Select( est )
			if ret==nil then 
				self:DebugDisp( est, "操作対象の取得に失敗" )
			end
			opc:Format( ret )
		end
		return opc
	end,
	
	-- 
	-- その他のメンバ関数
	--
	-- cnt, cnt / min, max を返す
	GetObjectMinMax = function( self, est, opdidx )
		self:pushSelf(est)
		local c1, c2 = 0, 0
		if self.operand and self.operand.GetMinMax then
			c1, c2 = self.operand:GetMinMax( est, opdidx )
		elseif self.operand and self.operand.Count then
			c1=self.operand:Count( est, false, opdidx )
			c2=c1
		end
		return c1, c2
	end,
	
	-- オブジェクトの領域をまとめて返す
	GetObjectLocation = function( self, est, opdidx )
		self:pushSelf(est):setCurOperand(opdidx)
		if self.operand==nil then return dev.location_info() end
		return self.operand:Location( est, opdidx )
	end,
	
	-- 操作対象となるカードを取得
	GetAllObject = function( self, est, opdidx )
		self:pushSelf(est)
		local r=self.operand:GetAll( est, false, opdidx )	
		return r
	end,
	
	-- アクションのとる引数の数
	GetActionArity = function( self )
		return self.action.arity
	end,
	
	-- フラグ
	AddFlag = function( self, flags )
		self.flags = bit.bor( self.flags, flags )
	end,
	TestFlag = function( self, f )
		return bit.btest( self.flags, f )
	end,
	
	--
	-- プライベート関数
	--	
	-- estに自身を積む
	pushSelf = function( self, est )
		if self.key==nil then
			dev.print("オペレーションに識別IDがありません AddOperationの使用漏れを確認してください")
			return nil
		end	
		local ops = est:pushOpState( self.key, dev.operation_state(self) )
		return ops
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
-- Operationの返り値
--
dev.op_result = dev.new_class(
{
	__init = function( self, cnt, opr, other )
		self.count = cnt
		self.operand = opr
		self.param = other
	end,	
	GetOperand = function( self, i )
		return self.operand:GetTable()[dev.option_arg(i,1)]
	end,
	GetCount = function( self )
		return self.count
	end,
	GetResult = function( self )
		return self.param
	end,
	Done = function( self, val )
		if val then return self.count>=val
		else return self.count>0 end
	end,
})

-- 
-- ================================================================================
--
--  !! 条件
--
-- ================================================================================
--
-- オブジェクトの数を調べる
dev.cond_count = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		local istarget = dev.option_arg( args.istarget, false )
		
		local oprs = {}
		for i, a in ipairs(args) do
			if i==1 then
				self.func = a
			elseif type(a)=="table" and a.Count then
				table.insert( oprs, function(est) return a:Count( est, istarget ) end )
			else
				table.insert( oprs, a )
			end
		end
		if self.func then
			self.func = self.func(oprs)
		end
		dev.print_table(oprs,"oprs")
	end,

	-- Check
	Eval = function( self, est )
		if self.func then
			return self.func:Eval( est )
		end
	end,
})

-- 指定数以上存在する
dev.cond_exist = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		self.o = args[1]
		self.istarget = dev.option_arg( args.istarget, false )
		self.cnt = args.count
	end,

	-- Check
	Eval = function( self, est )
		return self.o:Exists( est, self.istarget, self.cnt )
	end,
})

-- 存在しない
dev.cond_none_exist = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		self.o = args[1]
		self.istarget = dev.option_arg( args.istarget, false )
	end,

	-- Check
	Eval = function( self, est )
		return not self.o:Exists( est, self.istarget )
	end,
})

-- 
-- ================================================================================
--
--  !! オブジェクト
--
-- ================================================================================
--
--  コンセプト
-- : Exists est
-- : Select est
-- : GetAll est
-- : GetMinMax est
-- : Location est
--

--
-- =====================================================================
--
--  !! カード・チェーン等に対して行う操作をオブジェクト化
--
-- =====================================================================
--
-- CheckOperable		( self, est, c, operand-id ) -> boolean
-- Execute				( self, est, operand1, operand2... ) -> operated_count, another_operation_result
-- DoCheck				[opt]
-- OperationInfoParams	[opt] return ( Param, Player )
--

-- action 基底クラス
dev.action = dev.new_class(
{
	__init = function( self, cat, hint, arity )
		self.category 	= cat
		self.hint 		= hint
		self.arity 		= dev.option_arg(arity,1)
	end,
	CheckOperable = function() 
		return true
	end,
	CheckOperableSep = function(self, o, opr)
		if self.arity==1 then
			return self:CheckOperable(o)
		else
			return true
		end
	end,
})

