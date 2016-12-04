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
dev.zone_card = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, "table" )
		dev.require( args.location, dev.eval_able(dev.location_info) )
		
		self.location 	= args.location -- location_infoを生成する
		self.Exception 	= args.exception
		self.filter 	= dev.tail_est_object_filter( args.filter )
	end,

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
	
	GetFilter = function(self, istarget)
		if istarget then
			return function(c, est) return c:IsCanBeEffectTarget(est:GetEffect()) and self.filter:Invoke(c, est) end
		else
			return self.filter:Get()
		end
	end,
	
	-- メンバ関数
	GetAll = function(self, est, istarget)
		local l = self:Location(est)
		return Duel.GetMatchingGroup( 
			self:GetFilter(istarget), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	Count = function(self, est, istarget)
		local l = self:Location(est)
		return Duel.GetMatchingGroupCount( 
			self:GetFilter(istarget), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	GetMinMax = function(self, est)
		return 1, self:Count(est)
	end,
	
	GetFirst = function(self, est, istarget)
		local l = self:Location(est)
		return Duel.GetFirstMatchingCard( 
			self:GetFilter(istarget), l.player, l[1], l[2], self:GetException(est), est )
	end,
	
	Exists = function( self, est, istarget, reqnum )
		local l = self:Location(est)
		if reqnum==nil then reqnum=1 end
		
		local api = Duel.IsExistingMatchingCard
		if istarget then
			api = Duel.IsExistingTarget
		end
		return api( self.filter:Get(), l.player, l[1], l[2], reqnum, self:GetException(est), est )
	end,
	
	Select = function( self, est, istarget, gsel )
		if gsel~=nil then
			return gsel
		end
		return self:GetAll( est, istarget )
	end,
	
	SelectImpl = function( self, est, istarget, tp, selmin, selmax, gsel )
		if selmax==nil then selmax=self:Count() end	
		if selmin==nil then selmin=1 end
		local l = self:Location(est)
		
		local api = Duel.SelectMatchingCard
		if istarget then
			api = Duel.SelectTarget
		end
		local finalfilter = self.filter:Get()
		if gsel~=nil then
			finalfilter = function(c) return gsel:IsContains(c) end
		end
		return api( tp, finalfilter, l.player, l[1], l[2], selmin, selmax, self:GetException(est), est )		
	end,
	
	Match = function(self, est, istarget, c)
		local f = self:GetFilter(istarget)
		return f(c, est)
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
		dev.require( args, "table" )
		if args==nil then args = {} end
		args.location = zone( args.player )
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

--
-- 効果を発動しているカード自身
--
dev.this_card = dev.new_class( dev.zone_card,
{
	__init = function( self, args )
		args.filter = function(c, est) return c==est:GetHandler() end
		dev.super_init( self, args )
	end,
	
	GetAll = function(self, est)
		return Group.FromCards( est:GetHandler() )
	end,
	Count = function(self)
		return 1
	end,
	GetFirst = function(self, est)
		return est:GetHandler()
	end,
	GetMinMax = function(self)
		return 1, 1
	end,
	Exists = function(self, est)
		local l = self:Location( est )
		return est:GetHandler():IsLocation( l[1] )
	end,
	Select = function(self, est)
		return self:GetAll(est)
	end
})

--
--
--
dev.single_card = dev.new_class(
{
	__init = function( self, args )
		args.filter = function(c, est) return c==est:GetHandler() end
		dev.super_init( self, args )
	end,
	
	GetAll = function(self, est)
		return Group.FromCards( est:GetHandler() )
	end,
	Count = function(self)
		return 1
	end,
	GetFirst = function(self, est)
		return est:GetHandler()
	end,
	GetMinMax = function(self)
		return 1, 1
	end,
	Exists = function(self, est)
		local l = self:Location( est )
		return est:GetHandler():IsLocation( l[1] )
	end,
	Select = function(self, est)
		return self:GetAll(est)
	end	
})

--
-- 効果対象となるオブジェクトを選択
--
dev.target_sel = dev.new_class(
{
	__init = function( self, a1, a2 )
		if a2==nil then
			self.index = 1
			self.base = a1
		else 
			dev.require( a2, "number" )
			self.index = a1:AddTargetPart()
			self.base = a2
		end

		if not dev.is_class(self.base) then
			local cls=dev.option_arg(self.base.class, dev.sel)
			self.base=cls(self.base)
		end
	end,

	-- インターフェース関数
	Select = function( self, est, _istarget, gsel ) -- このSelectは対象決定時と効果解決時の２度呼ばれる
		local tg=nil
		if est.timing == dev.ontarget then
			tg=self.base:Select( est, true, gsel )
			est:GetEffectClass():TellTargetPart( est, self.index, tg )
			
		elseif est.timing == dev.onoperation then	
			tg=est:GetActivationTarget( self.index )
			if tg==nil then
				est:OpDebugDisp("Failed effect_state.GetTarget")
				return nil
			end
			
			-- 必要ならReselect
			local mi, mx = self.base:GetMinMax( est )
			if mx<tg:GetCount() then
				tg=self.base:Reselect( est, tg, mx )
			end
		end
		return tg
	end,
	
	Exists = function( self, est )
		return self.base:Exists( est, true )
	end,
	
	GetAll = function( self, est )
		return self.base:GetAll( est, true )
	end,	
	
	GetMinMax = function( self, est )
		return self.base:GetMinMax( est )
	end,
	
	Location = function( self, est )
		return self.base:Location( est )
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
		
		self.player = dev.option_arg( args.player, dev.you )
		self.hand = dev.option_arg( args.fromhand, false )
		
		local loc = LOCATION_DECK + dev.option_val(self.hand, LOCATION_HAND, 0)
		args.location = dev.location_info( 0, loc, loc )
		
		dev.super_init( self, args )
	end,
	
	GetAll = function( self, est )
		local g=Duel.GetReleaseGroup( self.player:GetPlayer(est), self.hand )
		if self.basefilter~=nil then
			g:Filter( self.basefilter, self:GetException(est), est )
		end
		return g
	end,
	
	Count = function( self, est )
		if self.basefilter~=nil then
			return self:GetAll():GetCount()
		else
			return Duel.GetReleaseGroupCount( self.player:GetPlayer(est), self.hand )
		end
	end,
	
	GetFirst = function( self, est )
		return self:GetAll(est):GetFirst()
	end,
	
	Exists = function( self, est, istarget, reqnum )
		reqnum=dev.option_arg(reqnum, 0)
		local api=dev.option_val( self.hand, Duel.CheckReleaseGroupEx, Duel.CheckReleaseGroup )
		return api( self.player:GetPlayer(est), self.basefilter, reqnum, self:GetException(est), est )
	end,
	
	SelectImpl = function( self, est, istarget, tp, selmin, selmax, gsel )
		local api=dev.option_val( self.hand, Duel.SelectReleaseGroupEx, Duel.SelectReleaseGroup )
		return api( tp, self.basefilter, selmin, selmax, self:GetException(est), est )
	end,
})
