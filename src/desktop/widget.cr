require "colorize"
require "yaml"

require "./node"
require "./switcher"

module Desktop
  class Widget < Gtk::Widget
    include Gio::ListModel
    include Enumerable(Item)

    Log = ::Log.for(self)

    getter root : Node?
    getter current_node : LeafNode?
    getter previous_node : LeafNode?
    getter n_widgets = 0_u32
    @old_n_widgets : UInt32 = 0_u32

    @layout = Layout.new
    getter switcher = Switcher.new

    @animation_signal_connection : GObject::SignalConnection?

    @[GObject::Property]
    property? maximized : Bool = false
    getter place_holder : Gtk::Widget?

    signal last_item_removed
    signal current_node_changed

    def initialize(@place_holder : Gtk::Widget? = nil)
      super(vexpand: true, hexpand: true, focusable: true, css_name: "desktop")

      @layout.desktop = self
      @switcher.parent = self
      @switcher.model = self
      self.layout_manager = @layout

      setup_actions
      setup_controllers
    end

    def add_item(item : Item) : Nil
      current_node = @current_node
      if current_node
        current_node.push_item(item)
      else
        layout_change do
          current_node = LeafNode.new(item)
          @root = Node.new(current_node)
          set_current_node(current_node)
        end
      end
      item.parent = self
      item.grab_focus
      @n_widgets += 1
      reset_model
    end

    def remove_widget
      root = @root
      node = @current_node
      return if node.nil? || root.nil?
      layout_change do
        self.maximized = false if maximized?

        item = node.pop_item
        item.unparent
        if root.empty?
          @root = @current_node = nil
          last_item_removed_signal.emit
        elsif node.empty?
          # Set current node to nil, otherwise it's re-added to the chain.
          @current_node = nil if node == @current_node
          next_node = node.next_node || root.leftist_child
          node.remove_from_chain
          set_current_node(next_node)
        end

        grab_focus
        @n_widgets -= 1
      end
    end

    private def layout_change(&)
      Log.info do
        spaces = "\n                             "
        "desktop.to_yaml.strip.should eq(<<-EOS)\n" \
        "                             #{to_yaml.lines.join(spaces)}\n" \
        "EOS"
      end
      current_node = @current_node
      Log.info { "desktop.print_list.should eq(\"#{current_node.print_list}\")" } if current_node
      @layout.save_old_positions
      return_value = yield

      start_animation
      @layout.layout_changed
      reset_model
      return_value
    end

    private def start_animation
      return unless @animation_signal_connection.nil?

      @layout.animation_position = 0.0
      @layout.layout_changed

      target = Adw::CallbackAnimationTarget.new(->@layout.animation_position=(Float64))
      animation = Adw::TimedAnimation.new(self, 0.0, 1.0, 250, target)
      @animation_signal_connection = animation.done_signal.connect(->on_animation_done)
      animation.play
    end

    def current_item : Item?
      @current_node.try(&.top_item)
    end

    def set_current_item(item : Item) : Nil
      Log.info { "new current item show be ##{item}" }
      each_leaf_node do |node|
        if node.includes?(item)
          node.bring_to_front(item)
          set_current_node(node)

          break
        end
      end
    end

    private def set_current_node(node : LeafNode) : Nil
      return if @current_node == node

      old_current_node = @current_node
      @current_node = node

      if old_current_node
        node.remove_from_chain

        old_current_node.selected = false
        node.next_node = old_current_node
        old_current_node.next_node = nil if old_current_node.next_node == node
        old_current_node.previous_node = node
      end

      node.selected = true
      normalize_tree(node)
      current_node_changed_signal.emit
      node
    end

    def update_current_node(widget : Gtk::Widget)
      root = @root
      return if root.nil?

      root.each_leaf_node do |node|
        if node.includes?(widget)
          set_current_node(node)
          next
        end
      end
    end

    private def each_leaf_node(&)
      node = @current_node
      while node
        yield(node)
        node = node.next_node
      end
    end

    def each(&) : Nil
      each_leaf_node do |node|
        node.each_item do |item|
          yield(item)
        end
      end
    end

    def grab_focus
      @current_node.try(&.top_item.grab_focus)
    end

    private def setup_actions
      group = Gio::SimpleActionGroup.new
      {% for direction in %w(top bottom right left) %}
        {% for action in %w(move focus) %}
          action = Gio::SimpleAction.new({{ "#{action.id}_#{direction.id}" }}, nil)
          action.activate_signal.connect { {{ "#{action.id}(#{direction.id.symbolize})".id }} }
          group.add_action(action)
        {% end %}
      {% end %}

      {% for action in %w(close_view) %}
        action = Gio::SimpleAction.new({{ action }}, nil)
        action.activate_signal.connect(->on_{{ action.id }}(GLib::Variant))
        group.add_action(action)
      {% end %}

      action = Gio::SimpleAction.new("dump_tree", nil)
      action.activate_signal.connect do
        Log.info { "Tree dump:\n#{to_yaml}" }
      end
      group.add_action(action)

      action = Gio::PropertyAction.new(name: "maximize_view", object: self, property_name: "maximized")
      group.add_action(action)

      insert_action_group("desktop", group)
    end

    private def setup_controllers
      shortcuts = {"desktop.dump_tree":     "F9",
                   "desktop.move_top":      "<Alt><Shift>Up",
                   "desktop.move_left":     "<Alt><Shift>Left",
                   "desktop.move_bottom":   "<Alt><Shift>Down",
                   "desktop.move_right":    "<Alt><Shift>Right",
                   "desktop.focus_top":     "<Alt>Up",
                   "desktop.focus_left":    "<Alt>Left",
                   "desktop.focus_bottom":  "<Alt>Down",
                   "desktop.focus_right":   "<Alt>Right",
                   "desktop.maximize_view": "<Ctrl><Shift>X"}

      controller = Gtk::ShortcutController.new(propagation_phase: :capture)
      shortcuts.each do |action, accel|
        action = Gtk::ShortcutAction.parse_string("action(#{action})")
        trigger = Gtk::ShortcutTrigger.parse_string(accel)
        shortcut = Gtk::Shortcut.new(action: action, trigger: trigger)
        controller.add_shortcut(shortcut)
      end

      key_ctl = Gtk::EventControllerKey.new(propagation_phase: :capture)
      key_ctl.key_pressed_signal.connect(->key_pressed(UInt32, UInt32, Gdk::ModifierType))
      key_ctl.key_released_signal.connect(->key_released(UInt32, UInt32, Gdk::ModifierType))
      add_controller(key_ctl)

      add_controller(controller)
    end

    private def key_pressed(key_val : UInt32, key_code : UInt32, modifier : Gdk::ModifierType) : Bool
      return Gdk::EVENT_PROPAGATE if @n_widgets < 2

      root = @root
      if root && modifier.control_mask? && key_val.in?({Gdk::KEY_Tab, Gdk::KEY_dead_grave})
        rotate_switcher(reverse: key_val == Gdk::KEY_dead_grave)
        return Gdk::EVENT_STOP
      end
      Gdk::EVENT_PROPAGATE
    end

    private def key_released(key_val : UInt32, key_code : UInt32, modifier : Gdk::ModifierType) : Bool
      return Gdk::EVENT_PROPAGATE if @n_widgets < 2

      root = @root
      if @switcher.visible && root && modifier.control_mask?
        return Gdk::EVENT_STOP if key_val.in?({Gdk::KEY_Tab, Gdk::KEY_dead_grave})

        stop_switcher
      end
      Gdk::EVENT_PROPAGATE
    end

    private def rotate_switcher(*, reverse : Bool)
      root = @root
      return if root.nil?

      if !@switcher.visible
        add_css_class("switching")
        reset_model
      end
      selected = @switcher.rotate(reverse: reverse)
      root.show_item(selected) if selected
    end

    private def stop_switcher
      remove_css_class("switching")
      selected = @switcher.stop
      if selected
        set_current_item(selected)
        self.maximized = false
      end
    end

    private def reset_model
      items_changed(0, @old_n_widgets, @n_widgets)
      @old_n_widgets = @n_widgets
    end

    def maximized=(value : Bool)
      # Do not maximize if there's no other leaf node.
      return unless @current_node.try(&.next_node)

      layout_change do
        previous_def(value)
        root = @root
        root.hide_overlaped_items if root && !value
      end
    end

    private def on_close_view(_v : GLib::Variant)
      remove_widget
    end

    private def on_animation_done
      root = @root
      return if root.nil?

      if @maximized
        root.maximize(@current_node)
      else
        root.maximize(nil)
        root.hide_overlaped_items
      end
      # While safe signals isn't implemented this is needed to avoid leak animation objects.
      animation_signal_connection = @animation_signal_connection
      if animation_signal_connection
        animation_signal_connection.disconnect
        @animation_signal_connection = nil
      end
    end

    def focus(direction : Direction)
      current_node = @current_node
      return false if current_node.nil?

      focus(current_node, direction)
    end

    def focus(node : LeafNode, direction : Direction) : LeafNode?
      Log.info { "desktop.focus(:#{direction.to_s.downcase})" }

      node_found = find(node, direction)
      return if node_found.nil? || maximized?

      set_current_node(node_found)
      reset_model
      node_found
    end

    def move(direction : Direction)
      current_node = @current_node
      return false if current_node.nil?

      move(current_node, direction)
    end

    def move(node : LeafNode, direction : Direction) : LeafNode?
      return if maximized?

      layout_change do
        Log.info { "desktop.move(:#{direction.to_s.downcase})" }
        dest_node = if node.can_split?
                      node.split(direction)
                    else
                      node_found = find(node, direction)
                      return if node_found.nil?
                      item = node.pop_item
                      node_found.push_item(item)
                      node_found
                    end
        set_current_node(dest_node)
        node.remove_from_chain if node.empty?
        dest_node
      end
    end

    private def normalize_tree(leaf : LeafNode)
      remove_non_root_nodes_with_single_child(leaf)
      merge_nodes_with_same_orientation(leaf)
    end

    private def remove_non_root_nodes_with_single_child(leaf : LeafNode)
      node = leaf.parent
      while node
        parent = node.parent
        if node.children.size == 1
          if parent.nil?
            child = node.children.first
            if child.is_a?(Node)
              node.remove_child(child)
              @root = child
            end
          else
            index = parent.children.index!(node)
            parent.remove_child(node)
            parent.insert_child(index, node.children.first)
          end
        end

        node = parent
      end
    end

    private def merge_nodes_with_same_orientation(leaf : LeafNode)
      node = leaf.parent
      while node
        parent = node.parent

        if parent && node.orientation == parent.orientation
          index = parent.children.index!(node)
          parent.remove_child(node)

          node.children.each do |child|
            parent.insert_child(index, child)
            index += 1
          end
        end
        node = parent
      end
    end

    private def find(node : LeafNode, direction : Direction) : LeafNode?
      orientation = direction.orientation
      parent = node.parent
      child = node
      child_index = -1
      while !parent.nil?
        if parent.orientation == orientation
          child_index = parent.children.index!(child)
          child_index = if direction.right? || direction.bottom?
                          child_index + 1
                        else
                          child_index - 1
                        end
          break if 0 <= child_index < parent.children.size
        end

        child = parent
        parent = parent.parent
      end

      return if parent.nil?

      sibling = parent.children[child_index]
      if direction.left? || direction.top?
        sibling.leftist_child
      else
        sibling.rightist_child
      end
    end

    @[GObject::Virtual]
    def snapshot(snapshot : Gtk::Snapshot)
      place_holder = @place_holder
      snapshot_child(place_holder, snapshot) if place_holder && place_holder.should_layout

      root = @root
      return if root.nil?

      moving_item = @current_node.try(&.top_item)
      root.each_leaf_node do |node|
        node.each_item do |item|
          snapshot_child(item, snapshot) if item != moving_item
        end
      end
      snapshot_child(moving_item, snapshot) if moving_item
      snapshot_child(@switcher, snapshot)
    end

    @[GObject::Virtual]
    def grab_focus : Bool
      @place_holder.try(&.grab_focus) || @current_node.try(&.grab_focus) || false
    end

    @[GObject::Virtual]
    def get_n_items : UInt32
      @n_widgets
    end

    def [](pos : Int32) : Gtk::Widget?
      node = @current_node
      offset = 0
      while node
        return node[pos - offset] if pos < offset + node.stack_size

        offset += node.stack_size
        node = node.next_node
      end
    end

    @[GObject::Virtual]
    def get_item(pos : UInt32) : GObject::Object?
      self[pos.to_i32]
    end

    @[GObject::Virtual]
    def get_item_type : UInt64
      Gtk::Widget.g_type
    end

    def print_list : String
      current_node.try(&.print_list) || "∅"
    end

    def to_yaml(width = 1920, height = 1080) : String
      root = @root
      return "∅" if root.nil?

      positions = Hash(Item, Rectangle).new
      root.size_allocate(0, 0, width, height) do |item, rect|
        positions[item] = rect
      end

      YAML.build do |yaml|
        root.to_yaml(yaml, positions, current_item)
      end
    end
  end
end

require "./layout"
