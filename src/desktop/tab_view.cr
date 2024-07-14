require "./widget"

module Desktop
  class TabView < Adw::Bin
    getter tab_view = Adw::TabView.new(shortcuts: :alt_digits)
    @tab_number = 0

    signal last_item_removed

    def initialize
      super(child: @tab_view)

      @tab_view.close_page_signal.connect(->on_close_page(Adw::TabPage))
    end

    def add_tab(item : Item, place_holder : Gtk::Widget? = nil)
      desktop = Widget.new(place_holder)
      desktop.add_item(item)
      desktop.last_item_removed_signal.connect { on_last_item_removed_from_page(desktop) }
      page = @tab_view.append(desktop)
      page.title = "Tab #{@tab_number += 1}"
      @tab_view.selected_page = page
    end

    def add_item(item : Item, *, page_index : Int32? = nil)
      if @tab_view.n_pages.zero?
        add_tab(item)
        return
      end

      page = if page_index
               @tab_view.nth_page(page_index)
             else
               @tab_view.selected_page
             end
      Widget.cast(page.child).add_item(item) if page
    end

    def current_desktop_widget : Widget?
      page = @tab_view.selected_page
      page.child.as(Widget) if page
    end

    def current_item : Item?
      current_desktop_widget.try(&.current_item)
    end

    def current_node_changed(item : Item)
      current_desktop_widget.try(&.update_current_node(item))
    end

    def each_item(&)
      @tab_view.n_pages.times do |page_index|
        page = @tab_view.nth_page(page_index)
        Widget.cast(page.child).each do |item|
          yield(item)
        end
      end
    end

    private def on_close_page(page : Adw::TabPage) : Bool
      @tab_view.close_page_finish(page, true)

      Log.fatal { @tab_view.n_pages }

      Gdk::EVENT_STOP
    end

    private def on_last_item_removed_from_page(widget : Widget)
      n_pages = @tab_view.n_pages
      Log.fatal { "n_pages: #{n_pages}" }
      if n_pages == 1
        last_item_removed_signal.emit
      else
        # @tab_view.page(widget)
        n_pages.times do |page_index|
          page = @tab_view.nth_page(page_index)
          if page.child == widget
            @tab_view.close_page(page)
            break
          end
        end
      end
    end
  end
end
