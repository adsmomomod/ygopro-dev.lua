--
-- =====================================================================
--
--  !! チェーンを組まない処理いろいろ
--
-- =====================================================================
--

-- filter_effect
dev.simple_eclass = dev.new_class(
{
	-- 状態クラス
	InitStateObject = function( self, est, ... )
		if est.timing == dev.oncondition then
			dev.table.insert_array( est, {"effect"}, {...} )
		elseif est.timing == dev.ontarget then
			dev.table.insert_array( est, {"effect", "tc"}, {...} )
		else
			return
		end
		est.tp = est:GetEffect():GetHandlerPlayer()
	end,
	
	SetOath = function( self )
		self:AddProperty(EFFECT_FLAG_OATH)
	end,
})

--
-- 特殊召喚できない
--
dev.effect.CannotSpecialSummon = function( self, issingle )
	self:Construct( dev.simple_eclass )
	self:SetCode( EFFECT_CANNOT_SPECIAL_SUMMON )
	self.SetTarget = function( s, filter )
		s.Target = function( est ) return filter(est:GetTarget(), est) end
	end
	
	if issingle then
		self:SetType( EFFECT_TYPE_SINGLE )
	else
		self:SetType( EFFECT_TYPE_FIELD )
		self:SetTargetPlayer( dev.both )
		
		self.InitStateObject = function( s, est, ... )
			if est.timing == dev.ontarget then
				dev.table.insert_array( est, {"effect", "sumcard", "sumplayer", "sumtype", "sumpos", "sumdest", "sumeffect"}, {...} )
				est.tc = est.sumcard
				est.tp = est.sumplayer
			else
				dev.super_call( s, "InitStateObject", est, ... )
			end
		end
	end
end
dev.effect.CannotSpecialSummonMe = function( self )
	dev.effect.CannotSpecialSummon( self, true )
end

--
-- フィールドから離れた場合～に行く
--
dev.effect.LeaveFieldRedirect = function( self )
	self:Construct( dev.simple_eclass )
	self:SetType(EFFECT_TYPE_SINGLE)
	self:SetCode(EFFECT_LEAVE_FIELD_REDIRECT)
	self:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	self:SetReset(RESET_EVENT+0x47e0000)
	
	self.SetDest = self.SetValue
	self:SetDest(LOCATION_REMOVED)
end

--
-- 
--
