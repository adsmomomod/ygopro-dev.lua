--
-- =====================================================================
--
--  !! チェーンを組んで発動する効果
--
-- =====================================================================
--

--
-- op
--
dev.active_op = dev.new_class(dev.op,
{
	__init = function( self, tim, a )
		dev.super_init( self, a )
		dev.require( tim, "number" )
		self.exectim = tim
	end,
	
	-- OpInfo
	SetOperationInfo = function( self, est, tg )
		local val, otp = 0, 0
		if self.action.OperationInfoParams~=nil then
			val, otp = self.action:OperationInfoParams( est )
		end
		if tg~=nil then
			local tgc=tg:GetCount()
			Duel.SetOperationInfo( 0, self.category, tg, tg:GetCount(), otp, val )
		else
			local onum=self:GetObjectMinMax( est, 1 ) -- 第一オブジェクトのみ
			Duel.SetOperationInfo( 0, self.category, nil, onum, otp, val )
		end
	end,
	
	-- インターフェース関数
	Execute = function( self, est, ocs )
		local r
		if est.timing == dev.ontarget then
			r=self:Target( est, ocs )
		end
		if est.timing == self.exectim then
			r=self:ExecuteAction( est, ocs )
		end
		return r
	end,
	
	Target = function( self, est, tg )
		self:SetOperationInfo( est, tg )
		return tg
	end,
}) 

--
-- カード等を対象とする効果
--
dev.active_target_op = dev.new_class(dev.active_op,
{
	__init = function( self, ... )
		dev.super_init( self, dev.onoperation, ... )
		self:AddFlag( dev.astarget )
	end,
	
	-- 指定のカードが条件に適合するか (chkcで使用)
	CheckCard = function( self, est, chkc )
		-- 複数のオペランドがあるケースには対応しない
		if self.action.arity>1 then
			return true
		end
		self:beginOp( est, 1 )
		return self.operand:Match( est, self:IsTakeTarget(), chkc )
	end,
	
	-- インターフェース関数
	-- Check
	Check = function( self, est )
		if est.chkc~=nil then
			return self:CheckCard( est, est.chkc )
		else
			return dev.op.Check( self, est ) -- opのCheck
		end
	end,
	
	-- Target
	--   tg 省略でSelectを呼び出し
	--      省略しないなら、対象カードに設定
	--
	Target = function( self, est, oprst )
		self:beginOp( est, 1, oprst )
		local sels=self:selOperand( est )
		if sels==nil or #sels==0 then return nil end
		
		local tg = sels[1] -- オペレーション情報登録用に一部
		self:DebugDisp( est, "target selected=", tg:GetCount() )
		self:SetOperationInfo( est, tg )
		return tg, self:exitOp(est)
	end,
}) 

--
-- effect_class
-- 
dev.activation_eclass = dev.new_class(
{
	__init = function( self )
		self._multitg = 0
	end,

	--
	-- 状態クラス
	--
	InitStateObject = function( self, est, e, tp, eg, ep, ev, re, r, rp, chk, chkc )
		est.effect = e
		est.tp = tp
		est.eg = eg
		est.ep = ep
		est.ev = ev
		est.re = re
		est.r = r
		est.rp = rp
		if chk then est.chk=(chk==0) end
		est.chkc = chkc
	end,
	
	GetOperationReason = function( self, est )
		if self.timing==dev.onoperation then
			return REASON_EFFECT
		else
			return REASON_COST
		end		
	end,
	
	--
	-- オペレーション関連
	--
	-- クラス
	cost_op 	= dev.op,
	side_op		= dev.op,
	main_op		= dev.active_op,
	target_op 	= dev.active_target_op,	
	
	-- 発動に必要なオペレーション
	MainCostOp = function( self, a )
		local op = self.cost_op( a )
		self:AddRequired( op, dev.oncost )
		return self:AddOperation( op, dev.oncost )
	end,	
	MainOp = function( self, a )
		local op = self.main_op( dev.onoperation, a )
		self:AddCategory( op.category )
		self:AddRequired( op, dev.ontarget )
		return self:AddOperation( op, dev.ontarget+dev.onoperation )
	end,
	MainTargetOp = function( self, a )
		local op = self.target_op( a )
		self:AddCategory( op.category )
		self:SetTakeTarget()
		self:AddRequired( op, dev.ontarget )
		return self:AddOperation( op, dev.ontarget+dev.onoperation )
	end,
	MainActivationOp = function( self, a )
		local op = self.main_op( dev.ontarget, a )
		self:AddRequired( op, dev.ontarget )
		return self:AddOperation( op, dev.ontarget )
	end,
	
	-- 副次的なオペレーション
	SideCostOp = function( self, a )
		local op = self.side_op( a )
		return self:AddOperation( op, dev.oncost )
	end,
	SideOp = function( self, a )
		local op = self.side_op( a )
		return self:AddOperation( op, dev.onoperation )
	end,
	SideActivationOp = function( self, a )
		local op = self.side_op( a )
		return self:AddOperation( op, dev.ontarget )
	end,
	
	-- 発動条件を追加
	RequiredOnResolution = function( self, op )
		self:AddRequired( op, dev.onoperation )
	end,
	RequiredOnActivation = function( self, op )
		self:AddRequired( op, dev.ontarget )
	end,
	RequiredOnCost = function( self, op )
		self:AddRequired( op, dev.oncost )
	end,
	Required = function( self, op )
		self:AddRequired( op, dev.oncond )
	end,
	
	--
	-- 対象
	--
	ObtainTarget = function( self, est )
		local tg=Duel.GetChainInfo( 0, CHAININFO_TARGET_CARDS )
		return self:DivideTargetPart( est, tg )
	end,
	
	TellTargetPart = function( self, est, idx, tg )
		if self._multitg>1 then
			if idx==1 then
				est:SetLabelObject(tg)
				tg:KeepAlive()
				--dev.print("tell ",est:GetLabelObject())
			end
		end
	end,
	
	DivideTargetPart = function( self, est, tgs )
		if self._multitg==2 then
			local g1=est:GetLabelObject()
			local gs=tgs:Clone() -- tgsはリードオンリーっぽい
			gs:Sub(g1)
			
			return {g1, gs}
		else
			return {tgs}
		end
	end,
	
	AddTargetPart = function( self )
		local c=self._multitg
		self._multitg = c+1
		return c
	end,
	
	--
	--
	--
	Setup = function( self, args )
		if args and args.trigger then
			self:SetCode(args.trigger)
		else
			self:SetCode(EVENT_FREE_CHAIN)
		end
		if args and args.location then
			self:SetRange(args.location)
		end
	end,
})

--
--
-- effect
--
--
-- 魔法罠の発動
function dev.effect.Activation( self, args )
	effect_ctor( dev.activation_eclass, self, args )
	
	self:SetType(EFFECT_TYPE_ACTIVATE)
	self:SetRange(nil) -- 自動追加されるので
end

-- 起動効果
function dev.effect.Ignition( self, args )
	effect_ctor( dev.activation_eclass, self, args )
	
	self:SetType(EFFECT_TYPE_IGNITION)
	self:SetCode(0)
end

-- 誘発効果
-- 強制
function dev.effect.Trigger( self, args, t )
	effect_ctor( dev.activation_eclass, self, args )
	
	if args.optional or args.optional_if then
		self:ReplaceType( EFFECT_TYPE_TRIGGER_F, EFFECT_TYPE_TRIGGER_O )
		if args.optional_if then
			self:SetProperty( EFFECT_FLAG_DELAY )
		end
	else
		self:ReplaceType( EFFECT_TYPE_TRIGGER_O, EFFECT_TYPE_TRIGGER_F )
	end	
	self:AddType( t )
end
function dev.effect.SingleTrigger( self, args )
	dev.effect.Trigger( self, args, EFFECT_TYPE_SINGLE )
end
function dev.effect.FieldTrigger( self, args )
	dev.effect.Trigger( self, args, EFFECT_TYPE_FIELD )
end

-- 誘発即時効果
function dev.effect.QuickTrigger( self, args )
	effect_ctor( dev.activation_eclass, self, args )

	if self:GetCode()==EVENT_FREE_CHAIN or (args and args.optional) then
		self:SetType( EFFECT_TYPE_QUICK_O )
	else
		self:SetType( EFFECT_TYPE_QUICK_F )
	end	
end

-- リバース効果
function dev.effect.Flip( self, args )
	effect_ctor( dev.activation_eclass, self, args )
	
	if args and args.optional then
		self:SetType( EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP+EFFECT_TYPE_TRIGGER_O )
		self:SetProperty( EFFECT_FLAG_DELAY )
	else
		self:SetType( EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP+EFFECT_TYPE_TRIGGER_F )
	end
end
