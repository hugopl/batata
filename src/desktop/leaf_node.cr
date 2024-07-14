require "./item"

module Desktop
  class LeafNode
    @@next_id : Int32 = 0
    @id : Int32

    property parent : Node?
    property next_node : LeafNode?
    property previous_node : LeafNode?
    @selected = false
    @stack = Deque(Item).new
    @color : String

    def initialize(item : Item)
      @id = @@next_id += 1
      @color = ColorProvider.default.aquire
      push_item(item)
    end

    def self.reset_item_ids
      @@next_id = 0
    end

    delegate grab_focus, to: :top_item
    delegate empty?, to: @stack
    delegate includes?, to: @stack
    delegate :[], to: @stack

    def parent! : Node
      @parent.not_nil!
    end

    def push_item(item : Item) : Nil
      item.color = @color
      if @stack.size > 0
        previous_item = top_item
        previous_item.selected = false
        if previous_item.maximized?
          item.maximized = true
          # Only set visible=false on maximized, on other scenarios the previous widget
          # must be kept visible because of animations
          previous_item.visible = false
          previous_item.maximized = false
        end
      end

      @stack.unshift(item)
      update_item_properties
      item.grab_focus
    end

    def pop_item : Item
      item = @stack.shift
      item.selected = false

      parent = @parent
      if parent && @stack.empty?
        parent.remove_child(self)
      elsif @selected
        new_top_item = top_item
        new_top_item.visible = true
      end
      update_item_properties
      item
    end

    def show_item(item : Item) : Nil
      if @stack.includes?(item)
        @stack.each do |stack_item|
          found = stack_item == item
          stack_item.visible = found
          stack_item.selected = true
        end
      else
        @stack.each(&.selected=(false))
      end
    end

    def bring_to_front(item : Item) : Nil
      top_item.visible = false
      @stack.delete(item)
      push_item(item)
      item.visible = true
    end

    def remove_from_chain
      previous_node = @previous_node
      next_node = @next_node
      previous_node.next_node = next_node if previous_node
      next_node.previous_node = previous_node if next_node
      @next_node = @previous_node = nil
    end

    private def update_item_properties : Nil
      @stack.each do |item|
        item.selected = @selected
        item.stack_size = stack_size
      end
    end

    def stack_size
      @stack.size
    end

    def top_item : Item
      @stack.first
    end

    def top_item? : Item?
      @stack.first?
    end

    def leftist_child
      self
    end

    def rightist_child
      self
    end

    def each_item
      @stack.each do |item|
        yield(item)
      end
    end

    def can_split? : Bool
      @stack.size > 1
    end

    def split(direction : Direction)
      parent.not_nil!.split_child(self, direction)
    end

    def selected=(@selected)
      item = top_item?
      return if item.nil?

      item.selected = @selected
      item.grab_focus if @selected
    end

    def maximize(node : LeafNode?) : Nil
      top_item.maximized = (node == self)
    end

    def hide_overlaped_items
      @stack.each_with_index do |item, i|
        item.visible = i.zero?
      end
    end

    def to_yaml(yaml, positions : Hash, current_item : Gtk::Widget?)
      yaml.mapping do
        yaml.scalar("LeafNode#{@id}")
        yaml.sequence do
          @stack.each do |item|
            pos = "  [#{positions[item]}]" if item == top_item
            str = "#{item}#{pos}"
            str = "=#{str}" if item == current_item
            yaml.scalar(str)
          end
        end
      end
    end

    def print_list
      String.build { |io| print_list(io) }
    end

    def print_list(io : IO)
      inspect(io)
      io << "➜"
      next_node = @next_node
      if next_node
        next_node.print_list(io)
      else
        io << "Nil"
      end
    end

    def chain_info : String
      String.build do |io|
        io << "LeafNode" << @id << " prev=" << @previous_node.inspect << " next=" << @next_node.inspect
      end
    end

    def inspect(io : IO)
      io << "LeafNode" << @id << " {"
      @stack.each do |item|
        item.to_s(io)
        io << ","
      end
      io << "}"
    end
  end
end
