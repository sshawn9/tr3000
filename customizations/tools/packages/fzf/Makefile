# fzf, packaged from the upstream static ARM64 release binary.

include $(TOPDIR)/rules.mk

PKG_NAME:=fzf
PKG_VERSION:=0.74.4
PKG_RELEASE:=1

PKG_ARCH_NAME:=arm64
PKG_SOURCE:=fzf-$(PKG_VERSION)-linux_$(PKG_ARCH_NAME).tar.gz
PKG_SOURCE_URL:=https://github.com/junegunn/fzf/releases/download/v$(PKG_VERSION)/
PKG_HASH:=5d673b849f494f0d64ec471d8640b153ca8849e3846a31da17abdcfce8df6b46

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=

include $(INCLUDE_DIR)/package.mk

# Preserve the upstream prebuilt binary.
RSTRIP:=:

define Package/fzf
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Command-line fuzzy finder
  URL:=https://github.com/junegunn/fzf
  DEPENDS:=@aarch64
endef

define Package/fzf/description
  A general-purpose command-line fuzzy finder with built-in shell integration.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -xzf $(DL_DIR)/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/fzf/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/fzf $(1)/usr/bin/fzf
endef

$(eval $(call BuildPackage,fzf))
