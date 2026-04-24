include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-teamtalk
PKG_RELEASE:=1
PKG_VERSION:=1.0.0
PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=TeamTalk

LUCI_TITLE:=TeamTalk Server Manager
LUCI_DEPENDS:=+luci-base +luci-compat
LUCI_PKGARCH:=all
LUCIPKG_LANG:=en zh-cn
LUCI_PKGTYPE:=luci
LUCI_LANG_PO_DIR:=$(TOPDIR)/po

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/luci.mk

define Package/luci-app-teamtalk
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=TeamTalk Web UI
  DEPENDS:=$(LUCI_DEPENDS)
  MAINTAINER:=$(PKG_MAINTAINER)
endef

define Package/luci-app-teamtalk/install
  $(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
  $(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
  $(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/teamtalk
  $(INSTALL_DIR) $(1)/usr/share/teamtalk
  $(INSTALL_DIR) $(1)/etc/config
  $(INSTALL_DIR) $(1)/etc/init.d
  $(INSTALL_DIR) $(1)/usr/libexec/teamtalk

  $(INSTALL_DATA) $(TOPDIR)/luasrc/controller/teamtalk.lua $(1)/usr/lib/lua/luci/controller/teamtalk.lua
  $(INSTALL_DATA) $(TOPDIR)/luasrc/model/cbi/teamtalk.lua $(1)/usr/lib/lua/luci/model/cbi/teamtalk.lua

  $(CP) -r $(TOPDIR)/luasrc/view/teamtalk/* $(1)/usr/lib/lua/luci/view/teamtalk/
  $(CP) -r $(TOPDIR)/htdocs/adminkit/js $(1)/usr/share/teamtalk/
  $(INSTALL_DATA) $(TOPDIR)/root/etc/config/teamtalk $(1)/etc/config/
  $(INSTALL_BIN) $(TOPDIR)/root/etc/init.d/teamtalk $(1)/etc/init.d/
  $(INSTALL_BIN) $(TOPDIR)/root/usr/libexec/teamtalk/teamtalk-helper.sh $(1)/usr/libexec/teamtalk/
endef

$(eval $(call BuildPackage,luci-app-teamtalk))
