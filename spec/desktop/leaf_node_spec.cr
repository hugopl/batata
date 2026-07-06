require "../spec_helper"

describe Desktop::LeafNode do
  before_each do
    Desktop::Item.reset_item_ids
    Desktop::LeafNode.reset_item_ids
  end

  it "show_item selects only the shown item, deselecting the rest of the stack" do
    item1 = Desktop::Item.new
    item2 = Desktop::Item.new
    item3 = Desktop::Item.new
    node = Desktop::LeafNode.new(item1)
    node.push_item(item2)
    node.push_item(item3)

    node.show_item(item2)

    item1.selected?.should eq(false)
    item2.selected?.should eq(true)
    item3.selected?.should eq(false)
  end
end
