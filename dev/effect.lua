--
-- ====================================================
--
-- !! 効果
--
-- ====================================================
--
-- OperationInfo
--
function dev.SetOperationInfo( opcat, player, card, cardnum, opvalue )	
	if cardnum==nil then
		if card==nil then 
			cardnum=0
		elseif card.ForEach~=nil then -- cardがGroupかCardか調べている
			cardnum=card:GetCount()
		else
			cardnum=1
		end
	end	
	if player==nil then player=0 end
	Duel.SetOperationInfo( 0, opcat, card, cardnum, player, opvalue )	
end

--
-- FlagEffect
--
dev.flag_effect = dev.new_class(
{
	__init = function(self,code,reset,flag,count,initlabel,desc)
		self.code = code
		self.reset = reset
		self.flag = flag
		self.count = count
		self.initlabel = initlabel
		self.desc = desc
	end,
	Register = function(self, c)
		return c:RegisterFlagEffect(self.code, self.reset, self.flag, self.count, self.initlabel, self.desc)
	end,
	Test = function(self, c)
		return c:GetFlagEffect(self.code)
	end,
	Reset = function(self, c)
		return c:ResetFlagEffect(self.code)
	end,
	GetLabel = function(self, c)
		return c:GetFlagEffectLabel(self.code)
	end,
	SetLabel = function(self, c, label)
		return c:SetFlagEffectLabel(self.code, label)
	end,
})
dev.duel_flag_effect = dev.new_class(
{
	__init = function(self, code, reset, flag, count)
		self.code = code
		self.reset = reset
		self.flag = flag
		self.count = count
	end,
	Register = function(self, tp)
		return Duel.RegisterFlagEffect(tp, self.code, self.reset, self.flag, self.count)
	end,
	Test = function(self, tp)
		return Duel.RegisterFlagEffect(tp, self.code, self.reset, self.flag, self.count)
	end,
	Reset = function(self)
		return Duel.ResetFlagEffect(self.code)
	end,
})

--
-- 効果関連の関数
--
-- RelateToEffect
function dev.IsAllRelateToEffect( grp, e, exception )
	return not grp:IsExists(function(c,e) return not c:IsRelateToEffect(e) end, 1, exception, e)
end
function dev.GetFirstTarget( est )
	local tc=Duel.GetFirstTarget()
	if tc~=nil and tc:IsRelateToEffect( est:GetEffect() ) then return tc
	else return nil end
end
function dev.GetTargets( est )
	local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if g==nil then dev.print("dev.GetTargets: no target selected") return nil end
	
	local tg=g:Filter(Card.IsRelateToEffect, nil, est:GetEffect())
	if tg:GetCount()>0 then return tg
	else return nil end
end
function dev.GetTargetsAllRelate( est )
	local tg=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if tg==nil then dev.print("dev.GetTargetsAllRelate: no target selected") return nil end
	
	if dev.IsAllRelateToEffect(tg, est:GetEffect()) then return tg
	else return nil end
end
function dev.IsSelfRelate(args)
	local c=args:GetHandler()
	return c:IsRelateToEffect(args:GetEffect())
end

--
-- =============================================================================
--
--  !! 効果ライブラリ - 基本
-- 
-- =============================================================================
--
dev.effect = {}

-- 効果コンストラクタのひな形
local function effect_ctor( cls, self, args, ... )
	dev.instantiate( self, cls, ... )
	if args==nil then args={} end
	self:Setup( args )
end

-- 装備
function dev.effect.EquipmentActivation( cl )
	cl:SetCategory(CATEGORY_EQUIP)
	cl:SetType(EFFECT_TYPE_ACTIVATE)
	cl:SetCode(EVENT_FREE_CHAIN)
	cl:SetProperty(EFFECT_FLAG_CARD_TARGET)
end
function dev.effect.EquipmentLimit( cl )
	cl:SetType(EFFECT_TYPE_SINGLE)
	cl:SetCode(EFFECT_EQUIP_LIMIT)
	cl:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
end


