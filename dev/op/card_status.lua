--
-- =====================================================================
--
--  !! カードの状態を変更する操作
--
-- =====================================================================
--
-- 表示形式を変更
-- dev.do_poschange( POS_FACEUP_ATTACK, POS_DEFENSE ) 	-- 守備表示をすべて表側攻撃表示に
-- dev.do_poschange( dev.posswap, POS_FACEUP )			-- 表側表示のカードの表示形式を変更する
--
--[[
	dev.do_change_pos({
		*to = POS_FACEDOWN_DEFENSE
		from = POS_DEFENSE,
	})
]]
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

--
--
-- Aura
--
--
-- 任意の効果を登録
dev.do_set_aura = dev.new_class(dev.action,
{
	__init = function( self, cat, hint, cnt )
		dev.super_init( self, cat, hint )
		cnt = dev.option_arg(cnt,1)
		self.aura = {}
		for i=1, cnt do 
			self.aura[i] = dev.effect_class() 
		end
	end,
	CheckOperable = function( self, est, c ) 
		return true
	end,
	Execute = function( self, est, g )
		local c=est:GetHandler()
		local aes = {}
		for k, v in pairs(self.aura) do
			aes[k] = { dev.InitEffect( c, v ) }
		end
		return dev.Group.Sum( g, function(tc)
			for k, v in pairs(aes) do
				if dev.RegisterEffect( tc, aes[1], aes[2] ) then 
					return 1
				else 
					return 0 
				end
			end
		end )
	end,
})

-- 無効
dev.do_set_disabled = dev.new_class(dev.action,
{
	__init = function(self)
		dev.super_init( self, CATEGORY_DISABLE, HINTMSG_FACEUP )
		self.aura = dev.effect_class()
		self.aura:SetResetLeaveZone()
	end,
	CheckOperable = function( self, est, c ) 
		return c:IsFaceup() and not c:IsDisabled()
	end,
	Execute = function( self, est, g )
		local c=est:GetHandler()
		local e1=dev.InitEffect( c, self.aura )
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_DISABLE)
		local e2=dev.InitEffect( c, self.aura )
		e2:SetType(EFFECT_TYPE_SINGLE)
		e2:SetCode(EFFECT_DISABLE_EFFECT)
		
		local cnt = dev.Group.Sum( g, function(tc)
			if Duel.GetCurrentChain()>=2 then
				Duel.NegateRelatedChain(tc,RESET_TURN_SET)
				e2:SetValue(RESET_TURN_SET)
			end
			dev.RegisterEffect( tc, e1 )
			dev.RegisterEffect( tc, e2 )
			return 1
		end)
		return cnt
	end,
	
})
