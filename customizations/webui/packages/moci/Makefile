#
# MoCI - Modern Configuration Interface for OpenWrt (standalone ubus SPA).
#
# Upstream's Makefile expects a dist/ tree produced by a Node.js build step.
# Instead of adding Node to the host toolchain, this package takes upstream's
# own release artefact (the .ipk, which is architecture independent: every
# per-arch file in the release is byte-identical) through the regular OpenWrt
# download path so it is verified against PKG_HASH, then installs the parts
# that apply to a uhttpd/apk based system.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=moci
PKG_VERSION:=0.2.0
PKG_RELEASE:=1

PKG_SOURCE:=moci_$(PKG_VERSION)-r1_aarch64_cortex-a53.ipk
PKG_SOURCE_URL:=https://github.com/HudsonGraeme/MoCI/releases/download/$(PKG_VERSION)/
PKG_HASH:=04a18f1c8281ad8798a620ceb6c2b60c71a7fd322d6c335668ae316f8423736d

PKG_LICENSE:=MIT
PKG_MAINTAINER:=

include $(INCLUDE_DIR)/package.mk

define Package/moci
  SECTION:=admin
  CATEGORY:=Administration
  TITLE:=MoCI - Modern Configuration Interface for OpenWrt
  URL:=https://github.com/HudsonGraeme/MoCI
  PKGARCH:=all
  DEPENDS:=+rpcd +jsonfilter
endef

define Package/moci/description
  Standalone single-page web interface served from /www/moci, talking to the
  router through /ubus with its own rpcd ACL. Coexists with LuCI.
  Reachable at http://<router>/moci/
endef

define Package/moci/conffiles
/etc/config/moci
endef

# The .ipk is a tar.gz holding data.tar.gz; unpack that into root/.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/root
	tar -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) ./data.tar.gz
	tar -xzf $(PKG_BUILD_DIR)/data.tar.gz -C $(PKG_BUILD_DIR)/root
endef

define Build/Configure
endef

define Build/Compile
endef

# Not installed on purpose:
#   /etc/lighttpd/conf.d/50-moci.conf, /www/moci/ubus.cgi  - lighttpd (TurrisOS) only
#   /etc/opkg/moci-apps.conf, /etc/opkg/keys/*             - third-party opkg feed
#                                                              for optional add-ons
define Package/moci/install
	$(INSTALL_DIR) $(1)/www/moci
	$(CP) $(PKG_BUILD_DIR)/root/www/moci/index.html \
	      $(PKG_BUILD_DIR)/root/www/moci/app.css \
	      $(PKG_BUILD_DIR)/root/www/moci/manifest.json \
	      $(PKG_BUILD_DIR)/root/www/moci/icons \
	      $(PKG_BUILD_DIR)/root/www/moci/js \
	      $(1)/www/moci/
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/libexec/rpcd/moci $(1)/usr/libexec/rpcd/moci
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/usr/libexec/moci-pkg-call $(1)/usr/libexec/moci-pkg-call
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/root/usr/share/rpcd/acl.d/moci.json $(1)/usr/share/rpcd/acl.d/moci.json
	$(INSTALL_DIR) $(1)/usr/share/acl.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/root/usr/share/acl.d/moci.json $(1)/usr/share/acl.d/moci.json
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/root/etc/config/moci $(1)/etc/config/moci
endef

$(eval $(call BuildPackage,moci))
