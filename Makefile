include $(TOPDIR)/rules.mk

PKG_NAME:=selfheal
PKG_VERSION:=1.0
PKG_RELEASE:=1
COMPONENT:=selfheal
SHORT_DESCRIPTION:=Self-heal feature for system stability
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-v0.$(PKG_VERSION)
SOURCE_DIR:=$(CURDIR)/src

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/package/tinno/tinno.mk

define Package/selfheal
	SECTION:=tinno
	CATEGORY:=$(TINNO_SOFTWARE_CATEGORY)
	SUBMENU:=$(TINNO_APPLICATIONS)
	TITLE:=$(SHORT_DESCRIPTION)
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

