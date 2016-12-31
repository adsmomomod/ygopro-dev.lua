--
-- =====================================================================
--
--  !! カードの召喚・特殊召喚
--
-- =====================================================================
--
--
-- アクション
--
--

--
-- 召喚
--

-- 特殊召喚
--[[
	dev.do_special_summon({
		pos = POS_FACEUP,
		type = 0,
		nocheck = false,
		nolimit = false,
		player = you,
		zone_player = you,
	})
]]
dev.do_special_summon = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_SPECIAL_SUMMON, HINTMSG_SPSUMMON )
		if args==nil then args={} end
		self.sumpos = dev.option_arg(args.pos, POS_FACEUP)
		self.sumtype = dev.option_arg(args.type, 0)
		self.nocheck = dev.option_arg(args.nocheck, false)
		self.nolimit = dev.option_arg(args.nolimit, false)
		self.sumplayer = dev.option_arg(args.player, dev.you)
		self.sumtgplayer = dev.option_arg(args.zone_player, dev.you)
	end,
	
	--
	-- インターフェース関数
	--
	CheckOperable = function(self, est, c)
		local sump=dev.eval(self.sumplayer,est)
		return c:IsCanBeSpecialSummoned(est:GetEffect(), self.sumtype, sump, self.nocheck, self.nolimit)
	end,
	
	Execute = function(self, est, g) 
		local sump=dev.eval(self.sumplayer,est)
		local sumtp=dev.eval(self.sumtgplayer,est)
		return Duel.SpecialSummon(g, self.sumtype, sump, sumtp, self.nocheck, self.nolimit, self.sumpos)
	end,
	
	ActivationInfoParams = function( self, est )
		return self.sumplayer, 0
	end,
})

-- シンクロ召喚
--[[
	dev.do_special_summon({
		pos = POS_FACEUP,
		type = 0,
		nocheck = false,
		nolimit = false,
		player = you,
		zone_player = you,
	})
]]

dev.do_synchro_summon = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_SPECIAL_SUMMON, HINTMSG_SPSUMMON )
		self.tunerspec = dev.option_field( args, "specify_tuner", false )
		self.sumplayer = dev.option_field( args, "player", dev.you )
	end,
	
	--
	-- インターフェース関数
	--	
	Execute = function(self, est, syn, mat) 
		local c=syn:GetFirst()
		local sump=dev.eval(self.sumplayer,est)
		if self.tunerspec then
			local tuner=mat:GetFirst()
			Duel.SynchroSummon( sump, c, tuner )
		else
			Duel.SynchroSummon( sump, c, nil, mat )
		end
		return 1
	end,
	
	ActivationInfoParams = function( self, est )
		return self.sumplayer, LOCATION_EXTRA, 1
	end,
})


