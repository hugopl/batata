require "./leaf_node"

module Desktop
  class Node
    property orientation : Gtk::Orientation
    property children = [] of LeafNode | Node
    property parent : Node?

    def initialize(leaf : LeafNode, @orientation = Gtk::Orientation::Horizontal)
      insert_child(0, leaf)
    end

    delegate empty?, to: @children

    def each_leaf_node(&block : Proc(LeafNode, Nil))
      children.each do |child|
        if child.is_a?(LeafNode)
          block.call(child)
        else
          child.each_leaf_node(&block)
        end
      end
    end

    def insert_child(index : Int32, child : LeafNode | Node)
      @children.insert(index, child)
      child.parent = self
    end

    def remove_child(child : LeafNode | Node)
      @children.delete(child)
      child.parent = nil
      parent = @parent
      parent.remove_child(self) if parent && @children.empty?
    end

    def show_item(item : Item) : Nil
      @children.each(&.show_item(item))
    end

    def leftist_child
      @children.last.leftist_child
    end

    def rightist_child
      @children.last.rightist_child
    end

    def split_child(child : LeafNode, direction : Direction) : LeafNode?
      item = child.pop_item
      child_index = @children.index(child)
      raise ArgumentError.new("child not found") if child_index.nil?

      change_orientation_if_possible(direction)

      new_leaf = LeafNode.new(item)
      child_index += 1 if direction.right? || direction.bottom?
      if direction.orientation == @orientation
        insert_child(child_index, new_leaf)
      else
        child.parent!.remove_child(child)
        new_node = Node.new(child, direction.orientation)
        new_child_index = (direction.right? || direction.bottom?) ? -1 : 0
        new_node.insert_child(new_child_index, new_leaf)
        child_index -= 1 if direction.right? || direction.bottom?
        insert_child(child_index, new_node)
      end
      new_leaf
    end

    private def change_orientation_if_possible(direction : Direction)
      return unless @children.one?
      if (direction.top? || direction.bottom?) && @orientation.horizontal?
        @orientation = :vertical
      elsif (direction.left? || direction.right?) && @orientation.vertical?
        @orientation = :horizontal
      end
    end

    def accept(visitor : NodeVisitor)
      visitor.visit(self)
    end

    def maximize(node : LeafNode?) : Nil
      @children.each(&.maximize(node))
    end

    def hide_overlaped_items
      @children.each(&.hide_overlaped_items)
    end

    def size_allocate(@x : Int32, @y : Int32, @width : Int32, @height : Int32, &block : Proc(Item, Rectangle, Nil)) : Nil
      child_x = x
      child_y = y
      if @orientation.horizontal?
        child_width = width // @children.size
        child_height = height
      else
        child_width = width
        child_height = height // @children.size
      end

      @children.each do |child|
        if child.is_a?(Node)
          child.size_allocate(child_x, child_y, child_width, child_height, &block)
        else
          rect = Rectangle.new(child_x, child_y, child_width, child_height)
          child.each_item do |item|
            yield(item, rect)
          end
        end

        child_x += child_width if orientation.horizontal?
        child_y += child_height if orientation.vertical?
      end
    end

    def to_yaml(yaml, positions : Hash, current_widget : Gtk::Widget?)
      yaml.mapping do
        yaml.scalar(orientation.to_s)
        yaml.sequence do
          children.each do |node|
            node.to_yaml(yaml, positions, current_widget)
          end
        end
      end
    end

    def inspect(io : IO)
      io << "<Node " << @orientation << ' ' << @children << '>'
    end
  end
end
