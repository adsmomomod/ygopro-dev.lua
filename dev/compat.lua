--
-- ygopro <-> ADS 互換性対応
-- 基本ygopro基準
--

-- ygoproとADSで名前の違う定数に対応：ADSにygoproの名前の定数を追加する
local function gdef_ads_compat( name, adsname )
	if _G[name] == nil then
		_G[name] = _G[adsname]
	end
end

-- 
gdef_ads_compat("POS_FACEDOWN_DEFENSE", "POS_FACEDOWN_DEFENCE")
gdef_ads_compat("POS_FACEUP_DEFENSE", "POS_FACEUP_DEFENCE")
gdef_ads_compat("POS_DEFENSE", "POS_DEFENCE")

