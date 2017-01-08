--
-- =====================================================================
--
--  !! 召喚の手順
--
-- =====================================================================
--

-- アドバンス召喚のリリースは扱いが特殊？
dev.do_summon_tribute = dev.new_class(dev.action,
{
	__init = function( self )
		dev.super_init( self )
	end,
	Execute = function( self, est, tr )
		est:GetTarget():SetMaterial(tr)
		return Duel.Release( tr, REASON_SUMMON+REASON_MATERIAL )
	end,
})

-- 召喚用のリリースを選ぶ
dev.summon_tribute_sel = dev.new_class(dev.sel,
{
	__init = function( self, args )
		dev.require( args, {{ from = "table" }} )
		
		local fa=args.from 
		fa.location=dev.mzone(fa.player)
		args.from = dev.zone_card(fa)
		
		if fa.player==dev.opponent then
			self.opponent=true
		else
			self.opponent=(args.opponent~=nil)
		end
		
		dev.super_init( self, args )
	end,
	
	GetMinMax = function( self, est )
		local mi = dev.eval( self.selmin, est )
		return mi, mi
	end,
	
	Exists = function( self, est, istarget )
		local c=est:GetTarget()
		local cp=c:GetControler()
		if self.opponent then cp=1-cp end
		
		local mg=self:getSel( est, istarget )
		if Duel.GetLocationCount( cp, LOCATION_SZONE ) > -self.selmin then
			if Duel.GetTributeCount( c, mg, self.opponent ) >= self.selmin then
				return true
			end
		end
		return false
	end,
	
	Select = function( self, est, istarget )
		local c=est:GetTarget()
		local sp=dev.eval( self.select_player, est )
		
		local mg=self:getSel( est, istarget )
		return Duel.SelectTribute( sp, c, self.selmin, self.selmin, mg, self.opponent )
	end,
	
	getSel = function( self, est, istarget )
		if self.o then return self.o:Select( est, istarget ) end
		return nil
	end,
})

--
-- 召喚・特殊召喚の手順
-- 
dev.summon_proc_eclass = dev.new_class(
{
	InitStateObject = function( self, est, ... )
		if est.timing == dev.oncond then
			dev.table.insert_array( est, {"effect", "tc", "min_tribute"}, {...} )
		elseif est.timing == dev.ontarget then
			dev.table.insert_array( est, {"effect", "tc"}, {...} )
		elseif est.timing == dev.onoperation then
			dev.table.insert_array( est, {"effect", "tp", "eg", "ep", "ev", "re", "r", "rp", "tc"}, {...} )
		end
		if est.tp==nil then
			est.tp = est:GetEffect():GetHandlerPlayer()
		end
	end,
	
	GetOperationReason = function( self, est )
		return REASON_COST
	end,
	
	-- 設定
	SetSummonType = function( self, t )
		self:SetValue(t)
	end,
	
	SetSummonPos = function( self, pos, player )
		if player==nil then player=dev.you end
		self:AddProperty( EFFECT_FLAG_SPSUM_PARAM )
		self:SetTargetRange( pos, player:GetAbsolute() )
	end,
	
	--
	-- オペレーション
	--
	ProcOp = function( self, args )
		local op = dev.op( args )
		self:AddRequired( op, dev.oncond )
		return self:AddOperation( op, dev.onoperation )
	end,
	
	-- SUMMON_PROCのみ
	WithNoTribute = function( self )
		self:AddRequired( function(est)
			local c=est:GetTarget()
			return est.min_tribute==0 and Duel.GetLocationCount(c:GetControler(),LOCATION_MZONE)>0 
		end, dev.oncond )
	end,
	
	-- target
	SetSingleTarget = function( self, filter )
		self:SetSingleEffect()
		self:AddRequired( dev.HandlerFromFilter( filter ), dev.oncond )
	end,
	SetTargetRange = function( self, ... )
		self:SetTargetCardRange( ... )
	end,
	SetTarget = function( self, filter )
		self:SetTargetHandler( dev.HandlerFromFilter( filter ) )
	end,
	
	-- condition
	ConditionHandler = function( est, self )
		if est:GetTarget()==nil then	
			return true
		end		
		return dev.effect_class.ConditionHandler( est, self )
	end,
})

--
-- effect
--
local summonProcBase = function( self )
	self:Construct( dev.summon_proc_eclass )
	self:SetProperty( EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE )
end

-- 自身の召喚手順
dev.effect.SummonProc = function( self )
	summonProcBase( self )
	self:SetCode( EFFECT_SUMMON_PROC )
	self:SetType( EFFECT_TYPE_SINGLE )
end

-- 自身の唯一の召喚手順
dev.effect.LimitSummonProc = function( self )
	summonProcBase( self )
	self:SetCode( EFFECT_LIMIT_SUMMON_PROC )
	self:SetType( EFFECT_TYPE_SINGLE )
end

-- 自身の特殊召喚手順
dev.effect.SpecialSummonProc = function( self )
	summonProcBase( self )
	self:SetCode( EFFECT_SPSUMMON_PROC )
	self:SetType( EFFECT_TYPE_FIELD )
	self.SetSingleTarget = nil
end

-- 自身の唯一の特殊召喚手順
dev.effect.LimitSpecialSummonProc = function( self )
	dev.effect.SpecialSummonProc( self )
	self:ReplaceProperty( EFFECT_FLAG_CANNOT_DISABLE, 0 )
end

-- 自身のセット手順
dev.effect.SetProc = function( self )
	dev.effect.SummonProc( self )
	self:SetCode( EFFECT_SET_PROC )
end

-- 自身の唯一の召喚手順
dev.effect.LimitSetProc = function( self )
	dev.effect.LimitSummonProc( self )
	self:SetCode( EFFECT_LIMIT_SET_PROC )
end



