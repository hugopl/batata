module Desktop
  class Switcher < Adw::Bin
    Log = ::Log.for(self)

    @list_view : Gtk::ListView
    @selection_model : Gtk::SingleSelection

    @bind_connection : GObject::SignalConnection?
    @setup_connection : GObject::SignalConnection?

    def initialize
      super(css_name: "widget_switcher", visible: false)

      @selection_model = Gtk::SingleSelection.new(autoselect: false)
      @list_view = Gtk::ListView.new(model: @selection_model)
      @list_view.parent = self
    end

    def stop : Desktop::Item?
      self.visible = false

      @selection_model.selected_item.as?(Desktop::Item)
    end

    def rotate(reverse : Bool = false) : Desktop::Item?
      n_items = @selection_model.n_items
      return if n_items.zero?

      max_pos : UInt32 = n_items - 1
      pos : UInt32 = @selection_model.selected

      if !self.visible
        create_items
        self.visible = true
        pos = 1
      elsif reverse
        pos = pos.zero? ? max_pos : pos - 1
      else
        pos = pos == max_pos ? 0_u32 : pos + 1
      end
      @selection_model.selected = pos.to_u32
      @selection_model.selected_item.as(Desktop::Item)
    end

    def model=(model : Gio::ListModel)
      @selection_model.model = model
    end

    def create_items
      @setup_connection.try(&.disconnect)
      @bind_connection.try(&.disconnect)
      factory = Gtk::SignalListItemFactory.new
      @setup_connection = factory.setup_signal.connect(->setup_item(GObject::Object))
      @bind_connection = factory.bind_signal.connect(->bind_item(GObject::Object))
      @list_view.factory = factory
    end

    private def setup_item(obj : GObject::Object) : Nil
      list_item = Gtk::ListItem.cast(obj)
      list_item.child = Gtk::Label.new(halign: :fill)
    end

    private def bind_item(obj : GObject::Object)
      list_item = Gtk::ListItem.cast(obj)
      item = Desktop::Item.cast(list_item.item)
      label = Gtk::Label.cast(list_item.child)

      label.label = item.title
      label.css_classes.each { |css| label.remove_css_class(css) }
      label.add_css_class(item.color)
    end
  end
end
