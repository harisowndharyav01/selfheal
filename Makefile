include $(TOPDIR)/rules.mk

PKG_NAME:=selfheal
PKG_VERSION:=1.0
SHORT_DESCRIPTION:=Implementation of self-healing mechanisms for system stability
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/selfheal-v0.1.0
PKG_MAINTAINER:=Soft At Home <support.opensource@softathome.com>
PKG_LICENSE:=BSD-2-Clause-Patent
PKG_LICENSE_FILES:=LICENSE

COMPONENT:=selfheal

SOURCE_DIR:=$(TOPDIR)/custom_files/selfheal

include $(INCLUDE_DIR)/package.mk

define Package/selfheal
	SECTION:=examples
	CATEGORY:=Examples
	SUBMENU:=Plugins
	TITLE:=$(SHORT_DESCRIPTION)
	URL:=https://gitlab.com/prpl-foundation/components/core/plugins/selfheal
	DEPENDS += +libamxc +libamxp +libamxd +libamxo +amxrt +libsahtrace
	MENU:=1
endef

define SAHInit/Install
	install -d $(PKG_INSTALL_DIR)/etc/rc.d/
	ln -sfr $(PKG_INSTALL_DIR)/etc/init.d/$(COMPONENT) $(PKG_INSTALL_DIR)/etc/rc.d/S$(CONFIG_SAH_AMX_SELFHEAL_ORDER)$(COMPONENT)
	ln -sfr $(PKG_INSTALL_DIR)/etc/init.d/$(COMPONENT) $(PKG_INSTALL_DIR)/etc/rc.d/K$(CONFIG_SAH_AMX_SELFHEAL_ORDER)$(COMPONENT)
endef

define Package/$(PKG_NAME)/description
	Implementation of self-healing mechanisms to ensure system stability and resilience.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp -r $(SOURCE_DIR)/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(call Build/Compile/Default, \
		STAGINGDIR=$(STAGING_DIR) \
		CONFIGDIR=$(STAGING_DIR) \
		PKG_CONFIG_PATH=$(STAGING_DIR)/usr/lib/pkgconfig \
		LIBDIR=/usr/lib \
		INSTALL_LIB_DIR=/lib \
		INSTALL_BIN_DIR=/bin \
		RAW_VERSION=$(PKG_VERSION) \
		HARDCO_HAL_DIR=$(STAGING_DIR)/usr/include \
		CONFIG_SAH_AMX_SELFHEAL_ORDER=$(CONFIG_SAH_AMX_SELFHEAL_ORDER))
endef

define Build/Install
	$(call Build/Install/Default, \
		install INSTALL=install D=$(PKG_INSTALL_DIR) \
		DEST=$(PKG_INSTALL_DIR) \
		STAGINGDIR=$(STAGING_DIR) \
		CONFIGDIR=$(STAGING_DIR) \
		PV=$(PKG_VERSION) \
		PKG_CONFIG_LIBDIR=$(STAGING_DIR)/usr/lib/pkgconfig \
		LIBDIR=/usr/lib \
		INSTALL_LIB_DIR=/lib \
		INSTALL_BIN_DIR=/bin \
		RAW_VERSION=$(PKG_VERSION) \
		HARDCO_HAL_DIR=$(STAGING_DIR)/usr/include \
		CONFIG_SAH_AMX_SELFHEAL_ORDER=$(CONFIG_SAH_AMX_SELFHEAL_ORDER))
	$(call SAHInit/Install)
	@echo "Inside mypackage DEST(Build/Install):$(DEST)"
endef

define Build/InstallDev
	$(call Build/Install/Default, \
		install INSTALL=install D=$(STAGING_DIR) \
		DEST=$(STAGING_DIR) \
		STAGINGDIR=$(STAGING_DIR) \
		CONFIGDIR=$(STAGING_DIR) \
		PV=$(PKG_VERSION) \
		PKG_CONFIG_LIBDIR=$(STAGING_DIR)/usr/lib/pkgconfig \
		LIBDIR=/usr/lib \
		INSTALL_LIB_DIR=/lib \
		INSTALL_BIN_DIR=/bin \
		RAW_VERSION=$(PKG_VERSION) \
		HARDCO_HAL_DIR=$(STAGING_DIR)/usr/include \
		CONFIG_SAH_AMX_SELFHEAL_ORDER=$(CONFIG_SAH_AMX_SELFHEAL_ORDER))
	@echo "Inside mypackage DEST(Build/InstallDEV):$(DEST)"
endef

define Package/$(PKG_NAME)/install
	$(CP) $(PKG_INSTALL_DIR)/* $(1)/
	if [ -d ./files ]; then \
		$(CP) ./files/* $(1)/; \
	fi
	find $(1) -name '*.a' -exec rm {} +;
	find $(1) -name '*.h' -exec rm {} +;
	find $(1) -name '*.pc' -exec rm {} +;
endef

define Package/$(PKG_NAME)/config
	source "$(SOURCE)/Config.in"
endef

$(eval $(call BuildPackage,selfheal))
