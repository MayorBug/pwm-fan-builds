# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-pwm-fan-updater
PKG_VERSION:=0.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Georg Seema <georgseema@gmail.com>

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-pwm-fan-updater
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=Updater for LuCI PWM Fan Builds
  DEPENDS:=+luci-base +rpcd-mod-ucode +uclient-fetch +jsonfilter +luci-app-pwm-fan
  PKGARCH:=all
endef

define Build/Compile
endef

define Package/luci-app-pwm-fan-updater/install
	$(INSTALL_DIR) $(1)/www
	$(CP) ./htdocs/* $(1)/www/
	$(CP) ./root/* $(1)/
endef

define Package/luci-app-pwm-fan-updater/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || {
	rm -f /tmp/luci-indexcache
	rm -rf /tmp/luci-modulecache
	/etc/init.d/rpcd reload
}
exit 0
endef

$(eval $(call BuildPackage,luci-app-pwm-fan-updater))
