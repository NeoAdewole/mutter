module NavigationHelper
  # The published page tree for the whole site, loaded once per request and
  # shared by the navbar and whatever page is being rendered.
  def site_navigation
    @site_navigation ||= Page.navigation
  end

  # Built-in features of a section as [label, path] pairs.
  def built_in_links(section)
    section.built_ins.map { |built_in| [built_in.label, public_send(built_in.route)] }
  end

  def section_has_items?(section)
    section.built_ins.any? || site_navigation.fetch(section.key).any?
  end

  # A menu link that flags the page you are on, visually and for screen readers.
  def nav_link(label, path)
    current = current_page?(path)
    link_to label, path, class: ('menu-active' if current), aria: { current: ('page' if current) }
  end
end
