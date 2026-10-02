# zoxide, packaged from the upstream aarch64 musl release binary.

include $(TOPDIR)/rules.mk

PKG_NAME:=zoxide
PKG_VERSION:=0.10.0
PKG_RELEASE:=1

PKG_ARCH_NAME:=aarch64
PKG_SOURCE:=zoxide-$(PKG_VERSION)-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/ajeetdsouza/zoxide/releases/download/v$(PKG_VERSION)/
PKG_HASH:=f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

# Preserve the upstream prebuilt binary.
RSTRIP:=:

define Package/zoxide
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Smarter directory navigation
  URL:=https://github.com/ajeetdsouza/zoxide
  DEPENDS:=@aarch64 +fzf
endef

define Package/zoxide/description
  Track frequently used directories and jump to them with fuzzy matching.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/zoxide/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/zoxide $(1)/usr/bin/zoxide
	$(INSTALL_DIR) $(1)/usr/share/zsh/site-functions
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/completions/_zoxide $(1)/usr/share/zsh/site-functions/_zoxide
endef

$(eval $(call BuildPackage,zoxide))
