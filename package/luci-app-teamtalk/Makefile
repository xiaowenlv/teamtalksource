include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-teamtalk
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=TeamTalk
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-teamtalk
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=TeamTalk Web UI
  DEPENDS:=+luci-base +luci-compat
  PKGARCH:=all
endef

define Package/luci-app-teamtalk/description
 TeamTalk Server Manager LuCI interface.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Compile
endef

define Package/luci-app-teamtalk/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/teamtalk
	$(INSTALL_DIR) $(1)/usr/share/teamtalk
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/libexec/teamtalk
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n

	$(INSTALL_DATA) $(TOPDIR)/luasrc/controller/teamtalk.lua $(1)/usr/lib/lua/luci/controller/teamtalk.lua
	$(INSTALL_DATA) $(TOPDIR)/luasrc/model/cbi/teamtalk.lua $(1)/usr/lib/lua/luci/model/cbi/teamtalk.lua
	$(CP) $(TOPDIR)/luasrc/view/teamtalk/* $(1)/usr/lib/lua/luci/view/teamtalk/
	$(CP) -r $(TOPDIR)/htdocs/adminkit/js $(1)/usr/share/teamtalk/
	$(INSTALL_DATA) $(TOPDIR)/root/etc/config/teamtalk $(1)/etc/config/teamtalk
	$(INSTALL_BIN) $(TOPDIR)/root/etc/init.d/teamtalk $(1)/etc/init.d/teamtalk
	$(INSTALL_BIN) $(TOPDIR)/root/usr/libexec/teamtalk/teamtalk-helper.sh $(1)/usr/libexec/teamtalk/teamtalk-helper.sh
	$(INSTALL_DATA) $(TOPDIR)/po/en/teamtalk.po $(1)/usr/lib/lua/luci/i18n/teamtalk-en.po
	$(INSTALL_DATA) $(TOPDIR)/po/zh-cn/teamtalk.po $(1)/usr/lib/lua/luci/i18n/teamtalk-zh-cn.po
endef

$(eval $(call BuildPackage,luci-app-teamtalk))
