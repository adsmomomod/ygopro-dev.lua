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

-- カード等を対象とする効果
dev.active_target_op = dev.new_class(dev.op,
{
	__init = function( self, a )
		dev.super_init( self, a )
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
	
	Execute = function( self, est, ocs )
		local r
		if est.timing == dev.ontarget then
			r=self:Target( est, ocs )
		end
		if est.timing == dev.onoperation then
			r=self:ExecuteAction( est, ocs )
		end
		return r
	end,
	
	-- Target
	--   tg 省略でSelectを呼び出し
	--      省略しないなら、対象カードに設定
	--
	Target = function( self, est, oprst )
		local opst=self:beginOp( est, 1, oprst )
		local sels=self:selOperand( est, opst )
		if sels:Empty() then return end
		return self:exitOp(est)
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
	main_op		= dev.op,
	target_op 	= dev.active_target_op,	
	
	-- 発動に必要なオペレーション
	MainCostOp = function( self, a )
		local op = self.cost_op( a )
		self:AddRequired( op, dev.oncost )
		return self:AddOperation( op, dev.oncost )
	end,	
	MainOp = function( self, a, tgmode )
		local op, tim
		if tgmode then 
			op=self.target_op(a)
			tim=dev.ontarget+dev.onoperation
		else
			op=self.main_op(a)
			tim=dev.onoperation
		end
		self:AddCategory( op.action.category )
		self:AddRequired( op, dev.ontarget )
		local newop=self:AddOperation( op, tim )
		local info=a.opinfo
		if info~=false then
			if info==nil then info={} end
			if info.op==nil then info.op=op end
			self:AddActivationInfo(info)
		end
		return newop
	end,
	MainTargetOp = function( self, a )
		self:SetTakeTarget()
		return self:MainOp(a, true)
	end,
	MainActivationOp = function( self, a )
		local op = self.op(a)
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
	-- OpInfo
	--	
	-- 実際に登録
	SetActivationInfo = function( self, est, ent )
		if self:fillAcInfoCategory(ent)==nil then
			return
		elseif ent.op then
			ent.op.action:FillActivationInfo( est, ent, ent.op, dev.option_arg(ent.operand_index,1) )
		end	
		if ent.player==nil then ent.player=0 end
		if ent.value==nil then ent.value=0 end
		Duel.SetOperationInfo( 
			dev.option_arg(ent.insert_index,0), 
			ent.category,
			ent.cards, 
			dev.eval(ent.count,est),
			dev.eval(ent.player,est),
			dev.eval(ent.value,est)
		)
	end,
	
	-- 登録を予約する
	AddActivationInfo = function( self, entry )
		local ent=dev.table.shallowcopy(entry)
		if self:fillAcInfoCategory(ent)==nil then
			return
		end
		return self:AddOperation( function(est) self:SetActivationInfo(est, ent) end, dev.ontarget )
	end,
	
	fillAcInfoCategory = function( self, ent )
		local cat=dev.option_arg(ent.category, ent[1])
		if ent.op and cat==nil then
			cat=ent.op.action.act_category
		end
		ent.category = cat
		return cat
	end,
	
	--
	setup = function( self, args )
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
	self:Construct( dev.activation_eclass, args )	
	self:SetType(EFFECT_TYPE_ACTIVATE)
	self:SetRange(nil) -- 自動追加されるので
end

-- 起動効果
function dev.effect.Ignition( self, args )
	self:Construct( dev.activation_eclass, args )	
	self:SetType(EFFECT_TYPE_IGNITION)
	self:SetCode(0)
end

-- 誘発効果
-- 強制
function dev.effect.Trigger( self, args, t )
	self:Construct( dev.activation_eclass, args )
	
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
	self:Construct( dev.activation_eclass, args )

	if self:GetCode()==EVENT_FREE_CHAIN or (args and args.optional) then
		self:SetType( EFFECT_TYPE_QUICK_O )
	else
		self:SetType( EFFECT_TYPE_QUICK_F )
	end	
end

-- リバース効果
function dev.effect.Flip( self, args )
	self:Construct( dev.activation_eclass, args )
	
	if args and args.optional then
		self:SetType( EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP+EFFECT_TYPE_TRIGGER_O )
		self:SetProperty( EFFECT_FLAG_DELAY )
	else
		self:SetType( EFFECT_TYPE_SINGLE+EFFECT_TYPE_FLIP+EFFECT_TYPE_TRIGGER_F )
	end
end
