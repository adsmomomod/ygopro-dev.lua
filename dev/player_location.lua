
--
-- プレイヤー
--
dev.you_p = dev.new_class(
{
	Eval = function(self, est)
		return est:GetTargetPlayer()
	end,
	GetReverse = function(self)
		return dev.opponent
	end,
	GetAbsolute = function(self)
		return 0
	end,
	FormatRange = function(self, loc)
		return loc, 0
	end,
})
dev.opponent_p = dev.new_class(
{
	Eval = function(self, est)
		return 1-est:GetTargetPlayer()
	end,
	GetReverse = function(self)
		return dev.you
	end,
	GetAbsolute = function(self)
		return 1
	end,
	FormatRange = function(self, loc)
		return 0, loc
	end,
})
dev.both_p = dev.new_class(
{
	Eval = function(self)
		return PLAYER_ALL
	end,
	GetReverse = function(self)
		return dev.nilplayer -- none?
	end,
	GetAbsolute = function(self)
		return PLAYER_ALL
	end,
	FormatRange = function(self, loc)
		return loc, loc
	end,
})
dev.you 		= dev.you_p()
dev.opponent 	= dev.opponent_p()
dev.both 		= dev.both_p()

--
-- プレイヤーID, 場所1, 場所2　の情報
--
dev.location_info = dev.new_class(
{
	__init = function(self, p, l1, l2)
		self.player = dev.option_arg(p, nil)
		self[1] = dev.option_arg(l1, 0)
		self[2] = dev.option_arg(l2, 0)
		
		setmetatable( self, { __add = self.Add } )
	end,
	
	Add = function(l, r)
		local p=0
		if l.player==nil then
			p=1-r.player
		elseif r.player==nil then
			p=l.player
		end	
		
		l = l:GetFromOtherPlayer( p )
		return l
	end,
	
	-- ( p, 0, l ) を ( 1-p, l ) の形式に直す
	GetHead = function( self )
		if self[1]==0 and self[2]~=0 then
			return 1-self.player, self[2]
		else
			return self.player, self[1]
		end
	end,
	
	-- np基準にする
	GetFromOtherPlayer = function( self, np )
		local l1=self[1]
		local l2=self[2]
		if np~=self.player then
			l1 = self[2]
			l2 = self[1]
		end
		return dev.location_info( np, l1, l2 )
	end,
	
	Contains = function( self, c )
		local p, l = self:GetHead()
		return c:IsLocation(l)
	end,
})

--
-- 相対的な場所を表現
--
dev.relative_location = dev.new_class(
{
	__init = function( self, p, loc1, loc2 )
		self.player = dev.option_arg( p, dev.you )
		self.loc1 = dev.option_arg( loc1, 0 )
		self.loc2 = dev.option_arg( loc2, 0 )
		setmetatable( self, { __add = self.Add } )
	end,
	
	Eval = function( self, est )
		local l 
		local p = dev.eval(self.player,est)
		if p == PLAYER_ALL then
			l = dev.location_info( 0, self.loc1, self.loc1 )
		else
			l = dev.location_info( p, self.loc1, self.loc2 )
		end
		return l
	end,
	
	Add = function( l, r )
		l.loc1 = bit.bor( l.loc1, r.loc1 ) -- rのplayerは無視
		l.loc2 = bit.bor( l.loc2, r.loc2 ) -- rのplayerは無視
		--l.player = dev.combine_player( l.player, r.player )
		return l
	end,
})

local zone_binder = function(zonecode)
	return function(p)
		return dev.relative_location(p, zonecode)
	end
end
dev.mzone		= zone_binder(LOCATION_MZONE)
dev.szone		= zone_binder(LOCATION_SZONE)
dev.grave		= zone_binder(LOCATION_GRAVE)
dev.removed		= zone_binder(LOCATION_REMOVED)
dev.hand		= zone_binder(LOCATION_HAND)
dev.deck		= zone_binder(LOCATION_DECK)
dev.extradeck	= zone_binder(LOCATION_EXTRA)
dev.overlay		= zone_binder(LOCATION_OVERLAY)
dev.onfield		= zone_binder(LOCATION_ONFIELD)
dev.alllocation	= zone_binder(0xFF)

