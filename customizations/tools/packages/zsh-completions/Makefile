include $(TOPDIR)/rules.mk

PKG_NAME:=zsh-completions
PKG_VERSION:=0.36.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/zsh-users/$(PKG_NAME)/tar.gz/refs/tags/
PKG_SOURCE_URL_FILE:=$(PKG_VERSION)
PKG_HASH:=5aa68be2999a7be2eb56de8e4acff8f3bba4a66b9acbb233752536857408fb2e

PKG_LICENSE:=Zsh
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/zsh-completions
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Additional completion definitions for Zsh
  URL:=https://github.com/zsh-users/zsh-completions
  DEPENDS:=+zsh
  PKGARCH:=all
endef

define Package/zsh-completions/description
  Extend Zsh command and option completion with additional definitions.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/zsh-completions/install
	$(INSTALL_DIR) $(1)/usr/share/zsh/site-functions $(1)/usr/share/zsh/plugins/zsh-completions
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/_* $(1)/usr/share/zsh/site-functions/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/LICENSE $(1)/usr/share/zsh/plugins/zsh-completions/
endef

$(eval $(call BuildPackage,zsh-completions))
