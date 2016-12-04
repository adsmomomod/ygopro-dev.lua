
--
-- プレイヤー
--
dev.you_p = dev.new_class(
{
	GetPlayer = function(self, est)
		return est:GetTargetPlayer()
	end,
	GetReverse = function(self)
		return dev.opponent
	end,
})
dev.opponent_p = dev.new_class(
{
	GetPlayer = function(self, est)
		return 1-est:GetTargetPlayer()
	end,
	GetReverse = function(self)
		return dev.you
	end,
})
dev.both_p = dev.new_class(
{
	GetPlayer = function(self)
		return PLAYER_ALL
	end,
	GetReverse = function(self)
		return dev.nilplayer -- none?
	end,
})
dev.nil_p = dev.new_class(
{
	GetPlayer = function(self)
		return nil
	end,
	GetReverse = function(self)
		return nil
	end,
})
dev.combined_p = dev.new_class(
{
	__init = function( self, l, r )
		self.l = l
		self.r = r
	end,
})
dev.you 		= dev.you_p()
dev.opponent 	= dev.opponent_p()
dev.both 		= dev.both_p()
dev.nilplayer	= dev.nil_p()

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
	
	-- ( p, 0, l ) を ( 1-p, l, 0 ) の形式に直す
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
})

--
-- cards プリセット
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
		local p = self.player:GetPlayer( est )
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
dev.mzone		= function(p) return dev.relative_location(p, LOCATION_MZONE) end
dev.szone		= function(p) return dev.relative_location(p, LOCATION_SZONE) end
dev.grave		= function(p) return dev.relative_location(p, LOCATION_GRAVE) end
dev.removed		= function(p) return dev.relative_location(p, LOCATION_REMOVED) end
dev.hand		= function(p) return dev.relative_location(p, LOCATION_HAND) end
dev.deck		= function(p) return dev.relative_location(p, LOCATION_DECK) end
dev.extradeck	= function(p) return dev.relative_location(p, LOCATION_EXTRA) end
dev.overlay		= function(p) return dev.relative_location(p, LOCATION_OVERLAY) end
dev.onfield		= function(p) return dev.relative_location(p, LOCATION_ONFIELD) end


