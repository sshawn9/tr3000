# Starship prompt, packaged from the upstream aarch64 musl release binary.

include $(TOPDIR)/rules.mk

PKG_NAME:=starship
PKG_VERSION:=1.26.0
PKG_RELEASE:=1

PKG_ARCH_NAME:=aarch64
# Keep the download cache versioned; upstream's asset name has no version.
PKG_SOURCE:=starship-$(PKG_VERSION)-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/starship/starship/releases/download/v$(PKG_VERSION)/
PKG_SOURCE_URL_FILE:=starship-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_HASH:=dc30189378d2f2e287384e8a692d3f95ad1df64cf0e8c36aa9201516028aed6b

PKG_LICENSE:=ISC
PKG_LICENSE_FILES:=

include $(INCLUDE_DIR)/package.mk

# Preserve the upstream prebuilt binary.
RSTRIP:=:

define Package/starship
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Cross-shell prompt
  URL:=https://starship.rs/
  DEPENDS:=@aarch64
endef

define Package/starship/description
  A customizable prompt for interactive shells.
endef

define Package/starship/conffiles
/root/.config/starship.toml
endef

# The archive contains the binary at its root, without a source directory.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/starship/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/starship $(1)/usr/bin/starship
endef

$(eval $(call BuildPackage,starship))
