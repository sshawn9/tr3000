include $(TOPDIR)/rules.mk

PKG_NAME:=zsh-autosuggestions
PKG_VERSION:=0.7.1
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/zsh-users/$(PKG_NAME)/tar.gz/refs/tags/
PKG_SOURCE_URL_FILE:=v$(PKG_VERSION)
PKG_HASH:=0df7affff21cd87ed298e6a3970ed08a1dd66a6efa676454ee5b091ad503badf

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/zsh-autosuggestions
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Fish-like command autosuggestions for Zsh
  URL:=https://github.com/zsh-users/zsh-autosuggestions
  DEPENDS:=+zsh
  PKGARCH:=all
endef

define Package/zsh-autosuggestions/description
  Suggest commands as you type, using pluggable history strategies.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/zsh-autosuggestions/install
	$(INSTALL_DIR) $(1)/usr/share/zsh/plugins/zsh-autosuggestions
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/zsh-autosuggestions.zsh $(PKG_BUILD_DIR)/LICENSE \
		$(1)/usr/share/zsh/plugins/zsh-autosuggestions/
endef

$(eval $(call BuildPackage,zsh-autosuggestions))
