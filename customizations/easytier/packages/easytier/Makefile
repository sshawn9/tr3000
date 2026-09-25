#
# EasyTier mesh VPN - packaged from the upstream static aarch64 release binaries.
#
# Upstream distributes statically linked musl binaries and its own OpenWrt
# package (EasyTier/luci-app-easytier) also installs those instead of building
# with a Rust toolchain. This Makefile does the same, but through the regular
# OpenWrt download path so the archive is verified against PKG_HASH.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=easytier
PKG_VERSION:=2.6.4
PKG_RELEASE:=1

PKG_ARCH_NAME:=aarch64
PKG_SOURCE:=easytier-linux-$(PKG_ARCH_NAME)-v$(PKG_VERSION).zip
PKG_SOURCE_URL:=https://github.com/EasyTier/EasyTier/releases/download/v$(PKG_VERSION)/
PKG_HASH:=f533ec25a7ea714e09f645615012200278058525795cc3bb690ff011aec1a70f

# The archive unpacks into easytier-linux-<arch>/, not <name>-<version>/.
PKG_BUILD_DIR:=$(BUILD_DIR)/easytier-linux-$(PKG_ARCH_NAME)

PKG_LICENSE:=Apache-2.0
PKG_LICENSE_FILES:=
PKG_MAINTAINER:=

include $(INCLUDE_DIR)/package.mk

# Prebuilt, already stripped and statically linked.
RSTRIP:=:

define Package/easytier
  SECTION:=net
  CATEGORY:=Network
  TITLE:=A simple, decentralized mesh VPN with WireGuard support
  URL:=https://github.com/EasyTier/EasyTier
  DEPENDS:=@aarch64 +kmod-tun
endef

define Package/easytier/description
  EasyTier
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/easytier/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/easytier-core $(1)/usr/bin/easytier-core
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/easytier-cli $(1)/usr/bin/easytier-cli
endef

$(eval $(call BuildPackage,easytier))
