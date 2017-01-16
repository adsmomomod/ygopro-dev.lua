-- 
-- ================================================================================
--
--  !! カードオブジェクト : Card / Group
--
-- ================================================================================
--
--
-- ある場所にあるカードの集合
--
dev.zone_card = dev.new_class(dev.primal_object,
{
	__init = function( self, args )
		dev.require( args, "table" )
		dev.require( args.location, dev.eval_able(dev.location_info) )
		dev.super_init( self )
		
		self.location 	= args.location -- location_infoを生成する
		self.Exception 	= args.exception
		self.filter 	= dev.tail_est_object_filter( args.filter )
	end,

	-- メンバ関数
	GetException = function(self, est)
		if self.Exception then
			if type(self.Exception)=="function" then
				return self.Exception(est)
			elseif type(self.Exception)=="boolean" then
				return est:GetHandler()
			end
		else 
			return nil 
		end
	end,
	
	GetFilter = function(self, est, ignoretg)
		if not ignoretg and est:OperandState().target then
			return function(c, est) return c:IsCanBeEffectTarget(est:GetEffect()) and self.filter:Invoke(c, est) end
		else
			return self.filter:Get()
		end
	end,
	
	GetAllObject = function(self, est)
		local l = self:Location(est)
		return Duel.GetMatchingGroup( 
			self:GetFilter(est), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	CountObject = function(self, est)
		local l = self:Location(est)
		return Duel.GetMatchingGroupCount( 
			self:GetFilter(est), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	GetFirst = function(self, est)
		local l = self:Location(est)
		return Duel.GetFirstMatchingCard( 
			self:GetFilter(est), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	ExistsObject = function( self, est, reqnum )
		local l = self:Location(est)
		
		local api = Duel.IsExistingMatchingCard
		if est:OperandState().target then
			api = Duel.IsExistingTarget
		end		
		return api( self:GetFilter(est,true), l.player, l[1], l[2], reqnum, self:GetException(est), est )
	end,
	
	Select = function( self, est )
		local sg=self:GetAll(est)
		if est:OperandState().target and est:OperandState().source then
			Duel.SetTargetCard(sg)
		end
		return sg
	end,
	
	SelectImplObject = function( self, est, tp, selmin, selmax, gsrc )
		local l = self:Location(est)
		local istarget=est:OperandState().target
		
		if gsrc then
			gsrc=gsrc:Select( tp, selmin, selmax, nil )
			if istarget then
				Duel.SetTargetCard(gsrc)
			end
			return gsrc
		else
			local api = Duel.SelectMatchingCard
			if istarget then
				api = Duel.SelectTarget
			end
			return api( tp, self:GetFilter(est,true), l.player, l[1], l[2], selmin, selmax, self:GetException(est), est )	
		end
	end,
	
	Location = function(self, est)
		return dev.eval( self.location, est )
	end,
})

--
-- 領域をあらかじめ設定したもの
--  player - 領域のコントローラ－
--
local bind_zone = function( zone )
	return function( args )
		if args==nil then args = {} end
		args.location = zone( args[1] )
		return dev.zone_card( args )
	end
end
dev.mzone_card 		= bind_zone( dev.mzone )
dev.szone_card 		= bind_zone( dev.szone )
dev.grave_card 		= bind_zone( dev.grave )
dev.removed_card 	= bind_zone( dev.removed )
dev.hand_card 		= bind_zone( dev.hand )
dev.deck_card 		= bind_zone( dev.deck )
dev.extradeck_card 	= bind_zone( dev.extradeck )
dev.overlay_card 	= bind_zone( dev.overlay )
dev.onfield_card 	= bind_zone( dev.onfield )
dev.any_card 		= bind_zone( dev.alllocation )

--
-- あるゾーンのカードを一つだけ指定する
--
dev.spec_zone_card = dev.new_class( dev.zone_card,
{
	__init = function( self, args )
		dev.super_init( self, args )
		self.cards = args.from
	end,
	GetAllObject = function( self, est )
		local g=dev.eval(self.cards, est)
		return g:Filter(self:GetFilter(est), self:GetException(est), est)
	end,
	CountObject = function( self, est )
		local g=dev.eval(self.cards, est)
		return g:FilterCount(self:GetFilter(est), self:GetException(est), est)
	end,
	ExistsObject = function( self, est, mi )
		local l = self:Location(est)
		local g = dev.eval(self.cards, est)
		return g:IsExists(self:GetFilter(est), mi, self:GetException(est), est)
	end,
	SelectImplObject = function( self, est, tp, selmin, selmax )
		local sg=dev.eval(self.cards, est)			
		sg=sg:FilterSelect(tp, self:GetFilter(est), selmin, selmax, self:GetException(est), est)
		
		if est:OperandState().target then
			Duel.SetTargetCard(sg)
		end
		return sg
	end,
	
	--
	getOutSource = function(self, est)
		local gsrc=est:OperandState().source
		if gsrc then
			local all=self:GetAllObject(est)
			return gsrc:Filter( function(c) return all:IsContains(c) end, nil )
		end
		return nil
	end,
})

-- 効果を発動しているカード自身
dev.this_card = dev.new_class( dev.spec_zone_card,
{
	__init = function( self, args )
		args.from = function(est) return Group.FromCards(est:GetHandler()) end
		dev.super_init( self, args )
	end
})


-- 攻撃対象
--[[
self:MainTargetOp{
	dev.do_equip(),
	dev.target{
		activation = dev.operands{
			[1] = dev.sel{
				max = 3, 
				min = 1,
				from = dev.grave_card{ filter = @filter end },
				pie = szone_pie:Consumer()
			},
			[2] = dev.op_operated( ssop )
		},
		resolution = dev.pick_sel{
			max = 3,
			from = dev.any_card{ filter = @filter dev.IsRelateToEffect(c,est) end }
		}
	}
}

dev.operands{
	[1] = dev.target_get{ 
		index = 2
		filter = 
	}
	[2] = dev.op_operated( )
}
]]--

--
-- 効果対象となるオブジェクトを選択
--
dev.target = dev.new_class(
{
	__init = function( self, args )
		if args==nil then args={} end
		self.base = args.activation
		self.rbase = args.resolution
		self.index = dev.option_arg(args.index, 1)
		
		if self.base.sel_options and self.rbase.sel_options then
			self.rbase:CompleteSelOptions(self.base)
		end
	end,
	
	getTarget = function( self, est )
		local tg=est:GetActivationTarget( self.index )
		if tg==nil then
			est:OpDebugDisp("Failed effect_state.GetTarget")
			return nil
		end
		return tg
	end,

	-- インターフェース関数
	Select = function( self, est ) -- このSelectは発動時と効果解決時の２度呼ばれる
		local tg=nil
		if est.timing == dev.ontarget then
			est:OperandState().target = true
			tg=self.base:Select( est )
			est:GetEffectClass():TellTargetPart( est, self.index, tg )
			
		elseif est.timing == dev.onoperation then
			tg=self:getTarget( est )
			est:OperandState().source = tg
			tg=self.rbase:Select( est )
		end
		return tg
	end,
	
	Exists = function( self, est )
		if est.timing == dev.onoperation then
			local tg=self:getTarget( est )
			est:OperandState().source = tg
			return self.rbase:Exists( est )
		else
			est:OperandState().target = true
			return self.base:Exists( est )
		end
	end,
	
	GetAll = function( self, est )
		if est.timing == dev.onoperation then
			return self.rbase:GetAll( est )
		else
			est:OperandState().target = true
			return self.base:GetAll( est )
		end
	end,
	
	GetMinMax = function( self, est )
		if est.timing == dev.onoperation then
			return self.rbase:GetMinMax( est )
		else
			est:OperandState().target = true
			return self.base:GetMinMax( est )
		end
	end,
	
	Location = function( self, est )
		if est.timing == dev.onoperation then
			return self.rbase:Location( est )
		else
			est:OperandState().target = true
			return self.base:Location( est )
		end
	end,
})

-- targetオブジェクトを生成するヘルパクラス
dev.target_sel = dev.new_class( dev.target,
{
	__init = function( self, args )
		if args==nil then args={} end
		
		args.activation = dev.sel( args )
		
		local rfilter = function(c, est) 
			if not c:IsRelateToEffect( est:GetEffect() ) then return false end
			if args.resolve_filter and not args.resolve_filter(c, est) then return false end
			return not args.resolve_strict or args.from:Match(c, est)
		end
		
		if args.resolve_complete then
			args.resolution = dev.match{ from = dev.any_card(), filter = rfilter }
		else
			args.filter = rfilter
			args.resolution = dev.pick_sel{ from = dev.any_card(args) }
		end
		dev.super_init( self, args )
	end,
})

--
-- リリースするカード
--
--[[
	player : player = dev.you
	hand : boolean = false
]]
dev.tribute_card = dev.new_class( dev.zone_card,
{	
	__init = function( self, args )
		if args==nil then args = {} end
		dev.require( args, "table" )
		
		self.player = dev.option_arg( args[1], dev.you )
		self.hand = dev.option_arg( args.fromhand, false )
		
		local loc = LOCATION_DECK + dev.option_val(self.hand, LOCATION_HAND, 0)
		args.location = dev.location_info( 0, loc, loc )
		
		dev.super_init( self, args )
	end,
	
	GetAll = function( self, est )
		local g=Duel.GetReleaseGroup( dev.eval( self.player, est ), self.hand )
		if self.basefilter~=nil then
			g:Filter( self.basefilter, self:GetException(est), est )
		end
		return g
	end,
	
	Count = function( self, est )
		if self.basefilter~=nil then
			return self:GetAll():GetCount()
		else
			return Duel.GetReleaseGroupCount( dev.eval( self.player, est ), self.hand )
		end
	end,
	
	Select = function( self, est )
		return self:GetAll( est )
	end,
	
	GetFirst = function( self, est )
		return self:GetAll(est):GetFirst()
	end,
	
	Exists = function( self, est )
		local reqnum=dev.option_arg( est:OperandState().min, 1 )
		local api=dev.option_val( self.hand, Duel.CheckReleaseGroupEx, Duel.CheckReleaseGroup )
		return api( dev.eval( self.player, est ), self.basefilter, reqnum, self:GetException(est), est )
	end,
	
	SelectImpl = function( self, est )
		local selmin=dev.option_arg( est:OperandState().min, 1 )
		local selmax=dev.option_arg( est:OperandState().max, 1 )
		local tp=est:OperandState().select_player	
		local api=dev.option_val( self.hand, Duel.SelectReleaseGroupEx, Duel.SelectReleaseGroup )
		return api( tp, self.basefilter, selmin, selmax, self:GetException(est), est )
	end,
})

