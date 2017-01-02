--
-- =====================================================================
--
--  !! チェーンを組まない処理いろいろ
--
-- =====================================================================
--

-- filter_effect
dev.single_eclass = dev.new_class(
{
	-- 状態クラス
	InitStateObject = function( self, est, ... )
		if est.timing == dev.oncondition then
			dev.table.insert_array( est, {"effect"}, {...} )
			est.tp = est:GetEffect():GetHandlerPlayer()
		else
			return
		end
	end,
	
	-- Condition
	ConditionHandler = function( self, est )
		return self:Checkself.Condition( est )
	end,
})

-- 特殊召喚できない
dev.cannot_spsummon_eclass = dev.new_class(dev.simple_eclass,
{
	-- 状態クラス
	InitStateObject = function( self, est, ... )
		if est.timing == dev.ontarget then
			dev.table.insert_array( est, {"effect", "sumcard", "sumplayer", "sumtype", "sumpos", "sumdest", "sumeffect"}, {...} )
		end
		est.tc = est.sumcard
		est.tp = est.sumplayer
	end,
	
	setup = function( self, args )
		if args.oath then
			self:AddProperty(EFFECT_FLAG_OATH)
		end
		if args.target then
			local filter = args.target
			self.Target = function(est) return filter(est:GetTarget(), est) end
		end
		local player=dev.option_arg(args.player, dev.both)
		self:SetTargetRange( player:GetAbsolute() )
	end,
})

--c:RegisterNewEffect( dev.effect.LeaveFieldRedirect{ dest=LOCATION_REMOVED, owner=est:GetHandler() } )
--dev.RegisterNewEffect( est.tp, 
--[[
dev.effect.CannotSpecialSummon{ 
	oath=true, 
	player=dev.you
	target=@filter not c:IsType(TYPE_FUSION) end,
}

--
dev.effect.CannotSpecialSummon = dev.effect.Ctor( function( self, args )
	self:Construct( dev.cannot_spsummon_eclass, args )
	self:SetType(EFFECT_TYPE_FIELD)
	self:SetCode(EFFECT_CANNOT_SPECIAL_SUMMON)
	self:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	self:SetTargetRange(1,0)
	self:SetTarget(c63060238.splimit)
end )

function @effect.splimit(self)
	self:Inherit{ dev.effect.CannotSpecialSummon, oath=true }
	
	self.Target = function( est )
		return not est.GetTarget():IsType(TYPE_FUSION)
	end
end

]]--

-- フィールドから離れた場合～に行く
dev.effect.LeaveFieldRedirect = dev.effect.Builder(
	function( self, args )
		self:Construct( nil, args )
		self:SetType(EFFECT_TYPE_SINGLE)
		self:SetCode(EFFECT_LEAVE_FIELD_REDIRECT)
		self:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
		self:SetReset(RESET_EVENT+0x47e0000)
		self:SetValue(dev.option_arg(args.dest, LOCATION_REMOVED)) -- DECK/HAND/DECK/DECKBOT/DECKTOP
	end
)

