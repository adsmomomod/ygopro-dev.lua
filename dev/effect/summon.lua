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
-- effect_class
-- 
dev.summon_proc_eclass = dev.new_class(
{
	__init = function( self, field )
		self.isfield=field
	end,

	--
	-- 状態クラス
	--
	InitStateObject = function( self, est, ... )
		if est.timing == dev.oncond then
			dev.table.insert_array( est, {"effect", "tc", "min_tribute"}, {...} )
		elseif est.timing == dev.ontarget then
			dev.table.insert_array( est, {"effect", "tc"}, {...} )
		elseif est.timing == dev.onoperation then
			dev.table.insert_array( est, {"effect", "tp", "eg", "ep", "ev", "re", "r", "rp", "tc"}, {...} )
		end
		if est.tp==nil and est.tc~=nil then
			est.tp = est.tc:GetControler()
		end
	end,
	
	GetOperationReason = function( self, est )
		return REASON_COST
	end,
	
	-- 設定
	Setup = function( self, args )
		dev.require( args, "table" )
		
		-- type
		if args.type then
			self:SetValue(args.type)
		end
		-- target
		if args.target then
			local filter = args.target
			local fn = function(est) return filter(est:GetTarget(), est) end
			if self.isfield then
				self.Target = fn
			else
				self:AddRequired( fn, dev.oncond )
			end	
		end
		-- location
		if args.location then
			self:SetRange(args.location)
		end
		-- pos / opponent
		if args.opponent then
			self:AddProperty( EFFECT_FLAG_SPSUM_PARAM )
			self:SetTargetRange( args.opponent, 1 )
		end
	end,
	
	-- オペレーション
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
	
	AddCond = function( self, args )
		self:AddRequired( args, dev.oncond )
	end,
	
	-- condition
	ConditionHandler = function( self, est )
		self:DebugDisp("SetCondition Func Called (do)", est)
		if est:GetTarget()==nil then	
			return true
		end		
		if not self:CheckRequiredCondition( est ) then 
			self:DebugDisp("使用条件が満たされていません", est)
			return false
		elseif not est:CheckPieCounters() then 
			self:DebugDisp("Condition Pieが足りません", est)
			return false 
		end
		
		return true
	end,
})

--
--
-- effect
--
--
-- 召喚
function dev.effect.SummonProcBase( self, args, isfield, iseffect )
	effect_ctor( dev.summon_proc_eclass, self, args, isfield )
	self:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	if iseffect==true then
		self:AddProperty(EFFECT_FLAG_CANNOT_DISABLE)
	end	
	if isfield==true then
		self:SetType(EFFECT_TYPE_FIELD)
	else
		self:SetType(EFFECT_TYPE_SINGLE)
	end
end
function dev.effect.SummonProc( self, args )
	dev.effect.SummonProcBase( self, args )
	self:SetCode( EFFECT_SUMMON_PROC )
end
function dev.effect.OtherSummonProc( self, args )
	dev.effect.SummonProcBase( self, args, true )
	self:SetCode( EFFECT_SUMMON_PROC )
	if args.player then
		self:SetPlayerEffect( args.player )
	end
end
function dev.effect.LimitSummonProc( self, args )
	dev.effect.SummonProcBase( self, args )
	self:SetCode( EFFECT_LIMIT_SUMMON_PROC )
end

-- 特殊召喚
function dev.effect.SpecialSummonProc( self, args )
	dev.effect.SummonProcBase( self, args, true, true )
	self:SetCode(EFFECT_SPSUMMON_PROC)
end
function dev.effect.LimitSpecialSummonProc( self, args )
	dev.effect.SummonProcBase( self, args, true )
	self:SetCode(EFFECT_SPSUMMON_PROC)
end


