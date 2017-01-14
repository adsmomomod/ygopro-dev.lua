--
-- =====================================================================
--
--  !! カードの状態を変更する操作
--
-- =====================================================================
--
-- 表示形式を変更
-- dev.do_change_pos{ *to = POS_FACEDOWN_DEFENSE, from = POS_DEFENSE }
--
dev.do_change_pos = dev.new_class(dev.action,
{
	-- tbl / pos value
	__init = function( self, args )
		dev.super_init( self, CATEGORY_POSITION, HINTMSG_POSCHANGE )
		if args==nil then args={} end
		
		dev.require( args, {{ to = { "number", "table" } }} )
		
		self.poss = {
			[POS_FACEUP_ATTACK] = 0,
			[POS_FACEUP_DEFENSE] = 0, 
			[POS_FACEDOWN_ATTACK] = 0, 
			[POS_FACEDOWN_DEFENSE] = 0, 
		}
		for pre, _ in pairs(self.poss) do
			if args.from==nil or bit.btest(pre, args.from) then
				if type(args.to) == "table" then
					self.poss[pre] = dev.option_arg(args.to[pre], 0)
				else
					self.poss[pre] = args.to
				end
			end
		end
		
		self.noflip = dev.option_arg(args.noflipeffect, false)
		self.flipset = dev.option_arg(args.flipsetavailable, false)
	end,
	
	CheckOperable = function(self, est, c)
		local pre=c:GetPosition()
		local post=self.poss[pre]
		if post and post~=0 and pre~=post then
			if bit.btest(pre, POS_FACEUP) and bit.btest(post, POS_FACEDOWN) then
				return c:IsCanTurnSet()
			else
				return true
			end
		else
			return false
		end
	end,
	
	Execute = function(self, est, g) 
		return Duel.ChangePosition( g, 
			self.poss[POS_FACEUP_ATTACK], 
			self.poss[POS_FACEDOWN_ATTACK], 
			self.poss[POS_FACEUP_DEFENSE],
			self.poss[POS_FACEDOWN_DEFENSE],
			self.noflip, self.flipset
		)
	end
})

-- 表示形式を入れ替える（ルール通り）
dev.swapped_pos = {
	[POS_FACEUP_ATTACK] = POS_FACEUP_DEFENSE,
	[POS_FACEUP_DEFENSE] = POS_FACEUP_ATTACK,
	[POS_FACEDOWN_ATTACK] = POS_FACEDOWN_DEFENSE,
	[POS_FACEDOWN_DEFENSE] = POS_FACEUP_ATTACK,
}

-- すべてを入れ替える
dev.swapped_posface = {
	[POS_FACEUP_ATTACK] = POS_FACEDOWN_DEFENSE,
	[POS_FACEUP_DEFENSE] = POS_FACEDOWN_ATTACK,
	[POS_FACEDOWN_ATTACK] = POS_FACEUP_DEFENSE,
	[POS_FACEDOWN_DEFENSE] = POS_FACEUP_ATTACK,
}

-- 表示形式のみを入れ替える（裏表はそのままに）
dev.pure_swapped_pos = {
	[POS_FACEUP_ATTACK] = POS_FACEUP_DEFENSE,
	[POS_FACEUP_DEFENSE] = POS_FACEUP_ATTACK,
	[POS_FACEDOWN_ATTACK] = POS_FACEDOWN_DEFENSE,
	[POS_FACEDOWN_DEFENSE] = POS_FACEDOWN_ATTACK,
}

-- 表裏のみを入れ替える（表示形式はそのままに）
dev.pure_swapped_face = {
	[POS_FACEUP_ATTACK] = POS_FACEDOWN_ATTACK,
	[POS_FACEUP_DEFENSE] = POS_FACEDOWN_DEFENSE,
	[POS_FACEDOWN_ATTACK] = POS_FACEUP_ATTACK,
	[POS_FACEDOWN_DEFENSE] = POS_FACEUP_DEFENSE,
}

-- 確認する
dev.do_confirm = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, 0, HINTMSG_CONFIRM )
		self.player = dev.option_field( args, "player", dev.you )
	end,
	
	Execute = function( self, est, g )
		Duel.ConfirmCards( dev.eval( self.player, est ), g )
		return g:GetCount()
	end,
})

-- 無効
dev.do_negate_effect = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_DISABLE, HINTMSG_FACEUP )
		
		local aura = dev.effect_class()
		aura:SetType(EFFECT_TYPE_SINGLE)
		aura:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		aura:SetResetLeaveZone()
		if args.effect then
			aura:Inherit( args.effect )
		end
		if args.reset_phase then
			aura:SetResetPhase( args.reset_phase )
		end
		self.aura=dev.BuildEffectClass( aura )
		
		self.negchain=0
		if args.negate_chain then self.negchain=1 end
		if args.negate_chain_related then self.negchain=2 end
	end,
	CheckOperable = function( self, est, c ) 
		return c:IsFaceup() and not c:IsDisabled() 
			and (not c:IsType(TYPE_NORMAL) or bit.band(c:GetOriginalType(),TYPE_EFFECT)~=0)
	end,
	Execute = function( self, est, g )
		local c=est:GetHandler()
		
		local e1=dev.CreateEffect(self.aura, c)
		e1:SetCode(EFFECT_DISABLE)
		
		local e2=nil
		if self.negchain>0 then
			e2=e1:Clone()
			e2:SetCode(EFFECT_DISABLE_EFFECT)
			if self.negchain>1 then e2:SetValue(RESET_TURN_SET) end
		end
		
		local e3=e1:Clone()
		e3:SetCode(EFFECT_DISABLE_TRAPMONSTER)
		
		local tc=g:GetFirst()
		while tc do
			if self.negchain>1 then
				Duel.NegateRelatedChain(tc, RESET_TURN_SET)
			end
			
			tc:RegisterEffect( e1:Clone() )
			if e2 then tc:RegisterEffect( e2:Clone() ) end
			if tc:IsType(TYPE_TRAPMONSTER) then tc:RegisterEffect( e3:Clone() ) end
			
			tc=g:GetNext()
		end
		return g:GetCount()
	end,
})
