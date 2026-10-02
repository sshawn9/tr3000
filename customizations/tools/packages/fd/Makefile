# fd, packaged from the upstream aarch64 musl release binary.

include $(TOPDIR)/rules.mk

PKG_NAME:=fd
PKG_VERSION:=10.5.0
PKG_RELEASE:=1

PKG_ARCH_NAME:=aarch64
PKG_SOURCE:=fd-v$(PKG_VERSION)-$(PKG_ARCH_NAME)-unknown-linux-musl.tar.gz
PKG_SOURCE_URL:=https://github.com/sharkdp/fd/releases/download/v$(PKG_VERSION)/
PKG_HASH:=d76c4317f7d5dba69f8a2a15856c90c777e7f0dd4e85f0de8c76de6992c374d4

PKG_LICENSE:=MIT Apache-2.0
PKG_LICENSE_FILES:=LICENSE-MIT LICENSE-APACHE

include $(INCLUDE_DIR)/package.mk

# Preserve the upstream prebuilt binary.
RSTRIP:=:

define Package/fd
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Filesystem
  TITLE:=Fast file finder
  URL:=https://github.com/sharkdp/fd
  DEPENDS:=@aarch64
endef

define Package/fd/description
  A fast file finder with support for ignore files and regular expressions.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR) --strip-components=1
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/fd/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fd $(1)/usr/bin/fd
	$(INSTALL_DIR) $(1)/usr/share/zsh/site-functions
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/autocomplete/_fd $(1)/usr/share/zsh/site-functions/_fd
endef

$(eval $(call BuildPackage,fd))
