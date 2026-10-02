include $(TOPDIR)/rules.mk

PKG_NAME:=fzf-tab
PKG_VERSION:=1.3.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/Aloxaf/$(PKG_NAME)/tar.gz/refs/tags/
PKG_SOURCE_URL_FILE:=v$(PKG_VERSION)
PKG_HASH:=d75ac08c2c8af5a6a0478787b0f11fabbe24951973b7841ae963431e2070ee9a

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/fzf-tab
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Fuzzy completion menu for Zsh
  URL:=https://github.com/Aloxaf/fzf-tab
  DEPENDS:=+zsh +fzf
  PKGARCH:=all
endef

define Package/fzf-tab/description
  Select Zsh completion candidates interactively with fzf.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/fzf-tab/install
	$(INSTALL_DIR) $(1)/usr/share/zsh/plugins/fzf-tab
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/fzf-tab.zsh $(PKG_BUILD_DIR)/LICENSE \
		$(1)/usr/share/zsh/plugins/fzf-tab/
	$(CP) $(PKG_BUILD_DIR)/lib $(1)/usr/share/zsh/plugins/fzf-tab/
endef

$(eval $(call BuildPackage,fzf-tab))
