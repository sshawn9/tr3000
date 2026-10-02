# Atuin shell history, packaged from the upstream aarch64 musl release binary.

include $(TOPDIR)/rules.mk

PKG_NAME:=atuin
PKG_VERSION:=18.23.0
PKG_RELEASE:=1

PKG_ARCH_NAME:=aarch64
# Keep the download cache versioned; upstream's asset name has no version.
PKG_SOURCE:=atuin-$(PKG_VERSION)-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/atuinsh/atuin/releases/download/v$(PKG_VERSION)/
PKG_SOURCE_URL_FILE:=atuin-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_HASH:=faf91adc71e6b661b21ed4f486babbd7af9d17363d4276da4a0251f83c72498d

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

# Preserve the upstream prebuilt binary.
RSTRIP:=:

define Package/atuin
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Searchable shell history
  URL:=https://atuin.sh/
  DEPENDS:=@aarch64 +ca-bundle
endef

define Package/atuin/description
  Record shell history in a local SQLite database with interactive search
  and optional encrypted synchronization.
endef

define Package/atuin/conffiles
/root/.config/atuin/config.toml
endef

# The archive has an unversioned top-level directory.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/atuin/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/atuin $(1)/usr/bin/atuin
endef

$(eval $(call BuildPackage,atuin))
