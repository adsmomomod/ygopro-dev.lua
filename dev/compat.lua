--
-- ygopro基準 - ADS 互換性対応
--

-- ygoproにはあるがADSにはない定数を、ADSで使用する場合のために作成
local function gdef_ads_compat( name, adsname )
	if _G[name] == nil then
		_G[name] = _G[adsname]
	end
end

-- 
gdef_ads_compat("POS_FACEDOWN_DEFENSE", "POS_FACEDOWN_DEFENCE")
gdef_ads_compat("POS_FACEUP_DEFENSE", "POS_FACEUP_DEFENCE")
gdef_ads_compat("POS_DEFENSE", "POS_DEFENCE")

