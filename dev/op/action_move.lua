--
-- =====================================================================
--
--  !! カードに対する移動的動作
--
-- =====================================================================
--
-- 破壊
dev.do_destroy = dev.new_class(dev.action,
{
	__init = function(self, args)
		dev.super_init( self, CATEGORY_DESTROY, HINTMSG_DESTROY )
		self.dest = dev.option_field( args, "dest", nil )
	end,
	CheckOperable = function( self, est, c ) 
		return c:IsDestructable()
	end,
	Execute = function( self, est, g )
		return Duel.Destroy(g, est:GetTimingReason(), self.dest) 
	end,
})

-- 除外
--[[
	pos : number = POS_FACEUP
	temp
]]--
dev.do_remove = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_REMOVE, HINTMSG_REMOVE )
		self.removepos = dev.option_field( args, "pos", POS_FACEUP )
	end,
	
	CheckOperable = function( self, est, c )
		if est:IsTimingReason(REASON_COST) then 
			return c:IsAbleToRemoveAsCost() 
		else 
			return c:IsAbleToRemove()
		end
	end,
	
	Execute = function( self, est, g )
		return Duel.Remove( g, self.removepos, est:GetTimingReason() )
	end
})
dev.do_banish = dev.do_remove

-- デッキに戻す
--[[
	decktop : boolean = false
	deckbottom : boolean = false
	player : player = nil
]]
dev.do_sendto_deck = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_TODECK, HINTMSG_TODECK )
		if args and args.decktop then
			self.deckseq=0
		elseif args and args.deckbottom then
			self.deckseq=1
		else
			self.deckseq=2
		end
		self.player = dev.option_field( args, "player", nil )
	end,
	
	CheckOperable = function( self, est, c )
		if est:IsTimingReason(REASON_COST) then 
			return c:IsAbleToDeckAsCost() 
		else 
			return c:IsAbleToDeck()
		end
	end,
	
	Execute = function( self, est, g )
		return Duel.SendtoDeck( g, self.player, self.deckseq, est:GetTimingReason() ) 
	end
})

-- 墓地に送る
dev.do_sendto_grave = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_TOGRAVE, HINTMSG_TOGRAVE )
	end,
	
	CheckOperable = function( self, est, c )
		if est:IsTimingReason(REASON_COST) then 
			return c:IsAbleToGraveAsCost() 
		else 
			return c:IsAbleToGrave()
		end
	end,
	
	Execute = function( self, est, g )
		local r=est:GetTimingReason()
		if self.discard then r=bit.bor(r, REASON_DISCARD) end	
		return Duel.SendtoGrave(g, r)
	end,
})

-- 手札から捨てる
dev.do_discard = dev.new_class(dev.do_sendto_grave,
{
	__init = function( self, args )
		dev.super_init( self, CATEGORY_HANDES, HINTMSG_DISCARD )
	end,
	
	CheckOperable = function( self, est, c )
		return c:IsDiscardable()
	end,	
	Execute = function( self, est, g )
		return Duel.SendtoGrave( g, bit.bor(est:GetTimingReason(), REASON_DISCARD) )
	end,
})

-- フィールドから手札に加える=手札に戻す
dev.do_sendto_hand = dev.new_class(dev.action,
{
	__init = function( self, args, cat, hint )
		if args==nil then args={} end
		
		dev.super_init( self, 
			dev.option_arg(cat, CATEGORY_TOHAND), 
			dev.option_arg(hint, HINTMSG_RTOHAND) )
	
		self.confirmer = args.confirm_player
		self.hander = args.hand_player
	
		if self.confirmer==nil then
			if self.hander~=nil then
				self.confirmer=self.hander:GetReverse()
			elseif self.hint==HINTMSG_ATOHAND then
				self.confirmer=dev.opponent
			end
		end
	end,
	
	CheckOperable = function( self, est, c ) 
		if est:IsTimingReason(REASON_COST) then 
			return c:IsAbleToHandAsCost() 
		else 
			return c:IsAbleToHand()
		end
	end,
	
	Execute = function( self, est, g ) 
		local hp=dev.eval( self.hander, est )
		local cnt=Duel.SendtoHand( g, hp, est:GetTimingReason() )
		local cp=dev.eval( self.confirmer, est )
		if cp then
			Duel.ConfirmCards( cp, g )
		end
		return cnt
	end,
})

-- デッキから手札に加える
function dev.do_search(args)
	local a=dev.do_sendto_hand( args, CATEGORY_TOHAND+CATEGORY_SEARCH, HINTMSG_ATOHAND )
	a.act_category=CATEGORY_TOHAND
	return a
end

-- フィールドとデッキ以外から手札に加える
function dev.do_salvage(args)
	return dev.do_sendto_hand( args, CATEGORY_TOHAND, HINTMSG_ATOHAND )
end


-- エクストラデッキに送る
dev.do_sendto_extra = dev.new_class(dev.action,
{
	__init = function( self, args )
		dev.super_init( self, 0, 0 )
	
		if args==nil then args={} end
		self.player = dev.option_arg(args.player, dev.you)
	end,
	
	CheckOperable = function( self, est, c ) 
		return c:IsType(TYPE_PENDULUM) and not c:IsForbidden()
	end,
	
	Execute = function( self, est, g ) 
		local tp=self.player:Eval( est )
		local cnt=Duel.SendtoExtraP( g, tp, est:GetTimingReason() )
		return cnt
	end,
})

-- リリースする
dev.do_tribute = dev.new_class(dev.action,
{
	__init = function( self )
		dev.super_init( self, CATEGORY_RELEASE )
		self.act_category = nil
	end,
	CheckOperable = function( self, est, c ) 
		return c:IsReleasable() and ( est:IsTimingReason(REASON_COST) or c:IsReleasableByEffect() )
	end,
	Execute = function( self, est, g )
		return Duel.Release( g, est:GetTimingReason() )
	end,
})

-- [1]を[2]に装備させる
dev.do_equip = dev.new_class(dev.action,
{
	__init = function(self, args)
		dev.super_init( self, CATEGORY_EQUIP, HINTMSG_EQUIP, 2 )
		self.up = dev.option_field(args, "up", true)
		self.zoneplayer = dev.option_field(args, "zone_player", dev.you)
	end,
	
	CheckOperable = function( self, est, eqc, tc ) 
		return eqc:CheckEquipTarget(tc)
	end,
	
	Execute = function( self, est, geq, gtarget )
		local cnt=0
		local zp=dev.eval( self.zoneplayer, est )
		
		-- 装備対象
		local ctg=gtarget:GetFirst()
		if not ctg:IsFaceup() then return false end
		
		-- 装備品
		local eqcnt = geq:GetCount()
		local ec=nil
		if eqcnt==1 then
			ec=geq:GetFirst() 
			if Duel.Equip( zp, ec, ctg, self.up ) then
				cnt=1
			end
		elseif eqcnt>1 then
			ec=geq:GetFirst()
			while ec do
				if Duel.Equip( zp, ec, ctg, self.up, true ) then
					cnt = cnt + 1
				end
				ec=geq:GetNext()
			end
			Duel.EquipComplete()
		end
		return cnt
	end,
})
dev.do_equip_tofield = dev.new_class(dev.do_equip,
{
	CheckOperableSep = function( self, est, c, opr ) 
		if opr==1 then return c:IsFaceup() end
		return true
	end,
})

-- エクシーズ素材にする
dev.do_toORU = dev.new_class(dev.action,
{
	__init = function( self ) end,
})
