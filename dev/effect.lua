--
--
-- 効果関連の単独で使う関数やクラス
--
--

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
--   local f = dev.flag_effect{ code=123456789, reset=RESET_EVENT+0x1fe0000 }
--   f:Register(e:GetHandler())
--	 f:Reset(e:GetHandler())
--   if f:Test(e:GetHandler()) then
--
dev.flag_effect = dev.new_class(
{
	__init = function( self, args )
		dev.require( args, {{ code = "number" }} )
		
		self.code = args.code
		self.reset = dev.option_arg( args.reset, 0 )
		self.flag = dev.option_arg( args.flag, 0 )
		self.count = dev.option_arg( args.count, 0 )
		self.label = args.label
		self.desc = args.desc
	end,
	Register = function(self, c)
		return c:RegisterFlagEffect(self.code, self.reset, self.flag, self.count, self.initlabel, self.desc)
	end,
	Get = function(self, c)
		return c:GetFlagEffect(self.code)
	end,
	Test = function(self, c)
		return self:Get(c)~=0
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

dev.duel_flag_effect = dev.new_class(dev.flag_effect,
{
	__init = function( self, args )
		dev.super_init( self, args )
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
	GetLabel = nil,
	SetLabel = nil,
})

--
-- 効果関連の関数
--
-- RelateToEffect
function dev.IsAllRelateToEffect( grp, e, exception )
	return not grp:IsExists(function(c,e) return not c:IsRelateToEffect(e) end, 1, exception, e)
end
function dev.IsSelfRelate( est )
	local c=est:GetHandler()
	return c:IsRelateToEffect( est:GetEffect() )
end
function dev.GetFirstTargetRelated( est )
	local tc=Duel.GetFirstTarget()
	if tc~=nil and tc:IsRelateToEffect( est:GetEffect() ) then return tc
	else return nil end
end
function dev.GetTargetsRelated( est )
	local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if g==nil then dev.print("dev.GetTargets: no target selected") return nil end
	
	local tg=g:Filter(Card.IsRelateToEffect, nil, est:GetEffect())
	if tg:GetCount()>0 then return tg
	else return nil end
end
function dev.GetTargetsAllRelated( est )
	local tg=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if tg==nil then dev.print("dev.GetTargetsAllRelate: no target selected") return nil end
	
	if dev.IsAllRelateToEffect( tg, est:GetEffect() ) then return tg
	else return nil end
end

--
-- 効果ライブラリ
--
dev.effect = {}

-- 効果コンストラクタのひな形
local function effect_ctor( cls, self, args, ... )
	dev.instantiate( self, cls, ... )
	if args==nil then args={} end
	self:Setup( args )
end


