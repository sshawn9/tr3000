include $(TOPDIR)/rules.mk

PKG_NAME:=zsh-syntax-highlighting
PKG_VERSION:=0.8.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/zsh-users/$(PKG_NAME)/tar.gz/refs/tags/
PKG_SOURCE_URL_FILE:=$(PKG_VERSION)
PKG_HASH:=5981c19ebaab027e356fe1ee5284f7a021b89d4405cc53dc84b476c3aee9cc32

PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=COPYING.md

include $(INCLUDE_DIR)/package.mk

define Package/zsh-syntax-highlighting
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=Shells
  TITLE:=Syntax highlighting for Zsh
  URL:=https://github.com/zsh-users/zsh-syntax-highlighting
  DEPENDS:=+zsh
  PKGARCH:=all
endef

define Package/zsh-syntax-highlighting/description
  Highlight commands and arguments in the interactive Zsh editor.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/zsh-syntax-highlighting/install
	$(INSTALL_DIR) $(1)/usr/share/zsh/plugins/zsh-syntax-highlighting
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/zsh-syntax-highlighting.zsh \
		$(PKG_BUILD_DIR)/.version $(PKG_BUILD_DIR)/.revision-hash $(PKG_BUILD_DIR)/COPYING.md \
		$(1)/usr/share/zsh/plugins/zsh-syntax-highlighting/
	for highlighter in $(PKG_BUILD_DIR)/highlighters/*/; do \
		name=$$$$(basename "$$$$highlighter"); \
		$(INSTALL_DIR) $(1)/usr/share/zsh/plugins/zsh-syntax-highlighting/highlighters/$$$$name; \
		$(INSTALL_DATA) $$$$highlighter/*.zsh \
			$(1)/usr/share/zsh/plugins/zsh-syntax-highlighting/highlighters/$$$$name/; \
	done
endef

$(eval $(call BuildPackage,zsh-syntax-highlighting))
