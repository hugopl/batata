require "../spec_helper"

describe Desktop::Widget do
  before_each do
    Desktop::Item.reset_item_ids
    Desktop::LeafNode.reset_item_ids
  end

  it "can be empty" do
    Desktop::Widget.new.empty?.should eq(true)
  end

  it "can iterate over widgets" do
    desktop = Desktop::Widget.new
    widgets = create_n_views(desktop, 4)
    desktop.print_list.should eq("LeafNode1 {Item4,Item3,Item2,Item1,}➜Nil")
    desktop.move(:right)
    desktop.print_list.should eq("LeafNode2 {Item4,}➜LeafNode1 {Item3,Item2,Item1,}➜Nil")
    desktop.focus(:left)
    desktop.print_list.should eq("LeafNode1 {Item3,Item2,Item1,}➜LeafNode2 {Item4,}➜Nil")
    desktop.move(:top)
    desktop.print_list.should eq("LeafNode3 {Item3,}➜LeafNode1 {Item2,Item1,}➜LeafNode2 {Item4,}➜Nil")
    desktop.to_a.sort.should eq(widgets.sort)
  end

  it "tracks number of widgets" do
    desktop = Desktop::Widget.new
    desktop.n_widgets.should eq(0)
    create_n_views(desktop, 2)
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
    desktop.n_widgets.should eq(2)

    desktop.move(:top)
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    desktop.n_widgets.should eq(2)

    desktop.remove_widget
    desktop.print_list.should eq("LeafNode1 {Item1,}➜Nil")
    desktop.n_widgets.should eq(1)

    desktop.remove_widget
    desktop.print_list.should eq("∅")
    desktop.n_widgets.should eq(0)
  end

  it "store a ordered list of items" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
    desktop.move(:left)
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
  end

  it "clean next_node reference" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)
    desktop.move(:left)
    desktop.move(:right)
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
  end

  it "can fetch widgets by index (1)" do
    desktop = Desktop::Widget.new
    desktop[0].should eq(nil)

    create_n_views(desktop, 4)
    desktop.print_list.should eq("LeafNode1 {Item4,Item3,Item2,Item1,}➜Nil")

    desktop.move(:left)
    desktop.print_list.should eq("LeafNode2 {Item4,}➜LeafNode1 {Item3,Item2,Item1,}➜Nil")
    desktop.focus(:right)
    desktop.print_list.should eq("LeafNode1 {Item3,Item2,Item1,}➜LeafNode2 {Item4,}➜Nil")
    desktop.move(:top)
    desktop.print_list.should eq("LeafNode3 {Item3,}➜LeafNode1 {Item2,Item1,}➜LeafNode2 {Item4,}➜Nil")
    desktop[0].to_s.should eq("Item3")
    desktop[1].to_s.should eq("Item2")
    desktop[2].to_s.should eq("Item1")
    desktop[3].to_s.should eq("Item4")

    desktop.focus(:bottom)
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜LeafNode3 {Item3,}➜LeafNode2 {Item4,}➜Nil")
    desktop.move(:left)
    desktop.print_list.should eq("LeafNode4 {Item2,}➜LeafNode1 {Item1,}➜LeafNode3 {Item3,}➜LeafNode2 {Item4,}➜Nil")
    desktop[0].to_s.should eq("Item2")
    desktop[1].to_s.should eq("Item1")
    desktop[2].to_s.should eq("Item3")
    desktop[3].to_s.should eq("Item4")
  end

  it "has a stack of views" do
    desktop = Desktop::Widget.new
    desktop.to_yaml.should eq("∅")
    desktop.print_list.should eq("∅")

    create_n_views(desktop, 1)
    desktop.empty?.should eq(false)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode1:
      - =Item1  [0,0 1920x1080]
    EOS
    desktop.print_list.should eq("LeafNode1 {Item1,}➜Nil")

    create_n_views(desktop, 2)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode1:
      - =Item3  [0,0 1920x1080]
      - Item2
      - Item1
    EOS
    desktop.print_list.should eq("LeafNode1 {Item3,Item2,Item1,}➜Nil")
  end

  it "can move stacks to top and unite back" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)

    desktop.move(:top)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Vertical:
    - LeafNode2:
      - =Item2  [0,0 1920x540]
    - LeafNode1:
      - Item1  [0,540 1920x540]
    EOS
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    desktop.move(:bottom)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Vertical:
    - LeafNode1:
      - =Item2  [0,0 1920x1080]
      - Item1
    EOS
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
  end

  it "can move stacks to bottom and unite back" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)

    desktop.move(:bottom)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Vertical:
    - LeafNode1:
      - Item1  [0,0 1920x540]
    - LeafNode2:
      - =Item2  [0,540 1920x540]
    EOS
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    desktop.move(:top)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Vertical:
    - LeafNode1:
      - =Item2  [0,0 1920x1080]
      - Item1
    EOS
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
  end

  it "can move stacks to left and unite back" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)

    desktop.move(:left)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode2:
      - =Item2  [0,0 960x1080]
    - LeafNode1:
      - Item1  [960,0 960x1080]
    EOS
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    desktop.move(:right)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode1:
      - =Item2  [0,0 1920x1080]
      - Item1
    EOS
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
  end

  it "can move stacks to right and unite back" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)

    desktop.move(:right)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode1:
      - Item1  [0,0 960x1080]
    - LeafNode2:
      - =Item2  [960,0 960x1080]
    EOS
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    desktop.move(:left)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode1:
      - =Item2  [0,0 1920x1080]
      - Item1
    EOS
    desktop.print_list.should eq("LeafNode1 {Item2,Item1,}➜Nil")
  end

  it "can split in 3 columns, then spit midle column in 2 rows" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 4)
    desktop.move(:right)
    desktop.focus(:left)
    desktop.move(:left)
    desktop.focus(:right)
    desktop.move(:bottom)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode3:
      - Item3  [0,0 640x1080]
    - Vertical:
      - LeafNode1:
        - Item1  [640,0 640x540]
      - LeafNode4:
        - =Item2  [640,540 640x540]
    - LeafNode2:
      - Item4  [1280,0 640x1080]
    EOS
  end

  it "can split in 3 columns, then spit midle column in 2 rows (II)" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 4)
    desktop.move(:right)
    desktop.focus(:left)
    desktop.move(:left)
    desktop.focus(:right)
    desktop.move(:top)
    desktop.to_yaml.strip.should eq(<<-EOS)
    ---
    Horizontal:
    - LeafNode3:
      - Item3  [0,0 640x1080]
    - Vertical:
      - LeafNode4:
        - =Item2  [640,0 640x540]
      - LeafNode1:
        - Item1  [640,540 640x540]
    - LeafNode2:
      - Item4  [1280,0 640x1080]
    EOS
    desktop.print_list.should eq("LeafNode4 {Item2,}➜LeafNode1 {Item1,}➜LeafNode3 {Item3,}➜LeafNode2 {Item4,}➜Nil")
  end

  it "do nothing if can't move" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 2)

    desktop.move(:top)
    desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")

    [Desktop::Direction::Top, Desktop::Direction::Right, Desktop::Direction::Left].each do |dir|
      desktop.move(dir)
      desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Vertical:
      - LeafNode2:
        - =Item2  [0,0 1920x540]
      - LeafNode1:
        - Item1  [0,540 1920x540]
      EOS
      desktop.print_list.should eq("LeafNode2 {Item2,}➜LeafNode1 {Item1,}➜Nil")
    end
  end

  it "can do complex split (1)" do
    desktop = Desktop::Widget.new
    create_n_views(desktop, 4)
    desktop.move(:left)
    desktop.focus(:right)
    desktop.move(:top)
    desktop.focus(:bottom)
    desktop.move(:left)
    desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Horizontal:
      - LeafNode2:
        - Item4  [0,0 960x1080]
      - Vertical:
        - LeafNode3:
          - Item3  [960,0 960x540]
        - Horizontal:
          - LeafNode4:
            - =Item2  [960,540 480x540]
          - LeafNode1:
            - Item1  [1440,540 480x540]
      EOS
    desktop.print_list.should eq("LeafNode4 {Item2,}➜LeafNode1 {Item1,}➜LeafNode3 {Item3,}➜LeafNode2 {Item4,}➜Nil")

    desktop.move(:left)
    desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Horizontal:
      - LeafNode2:
        - =Item2  [0,0 960x1080]
        - Item4
      - Vertical:
        - LeafNode3:
          - Item3  [960,0 960x540]
        - Horizontal:
          - LeafNode1:
            - Item1  [960,540 960x540]
      EOS
    desktop.print_list.should eq("LeafNode2 {Item2,Item4,}➜LeafNode1 {Item1,}➜LeafNode3 {Item3,}➜Nil")
  end

  context "when removing a widget" do
    it "keep a selected widget" do
      desktop = Desktop::Widget.new
      item1 = Desktop::Item.new
      item2 = Desktop::Item.new
      desktop.add_item(item1)
      desktop.add_item(item2)
      desktop.remove_widget
      item1.has_css_class("selected").should eq(true)
      item2.has_css_class("selected").should eq(false)
    end

    it "can remove the last widget" do
      desktop = Desktop::Widget.new
      create_n_views(desktop, 1)

      last_item_removed = false
      desktop.last_item_removed_signal.connect { last_item_removed = true }
      desktop.remove_widget
      last_item_removed.should eq(true)
      desktop.empty?.should eq(true)
      desktop.print_list.should eq("∅")
    end

    it "can remove nodes" do
      desktop = Desktop::Widget.new
      create_n_views(desktop, 2)
      desktop.move(:left)

      desktop.remove_widget
      desktop.to_yaml.strip.should eq(<<-EOS)
        ---
        Horizontal:
        - LeafNode1:
          - =Item1  [0,0 1920x1080]
        EOS
    end
  end

  context "when normalizing tree" do
    it "keep tree normalized" do
      desktop = Desktop::Widget.new
      create_n_views(desktop, 3)
      desktop.move(:left)
      desktop.focus(:right)
      desktop.move(:bottom)
      desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Horizontal:
      - LeafNode2:
        - Item3  [0,0 960x1080]
      - Vertical:
        - LeafNode1:
          - Item1  [960,0 960x540]
        - LeafNode3:
          - =Item2  [960,540 960x540]
      EOS
      desktop.move(:top)
      desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Horizontal:
      - LeafNode2:
        - Item3  [0,0 960x1080]
      - LeafNode1:
        - =Item2  [960,0 960x1080]
        - Item1
      EOS
    end

    it "removes empty non-leaf nodes creating a new root" do
      desktop = Desktop::Widget.new
      create_n_views(desktop, 3)
      desktop.move(:right)
      desktop.focus(:left)
      desktop.move(:bottom)
      desktop.focus(:right)
      desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Horizontal:
      - Vertical:
        - LeafNode1:
          - Item1  [0,0 960x540]
        - LeafNode3:
          - Item2  [0,540 960x540]
      - LeafNode2:
        - =Item3  [960,0 960x1080]
      EOS
      desktop.print_list.should eq("LeafNode2 {Item3,}➜LeafNode3 {Item2,}➜LeafNode1 {Item1,}➜Nil")

      desktop.move(:left)
      desktop.to_yaml.strip.should eq(<<-EOS)
      ---
      Vertical:
      - LeafNode1:
        - Item1  [0,0 1920x540]
      - LeafNode3:
        - =Item3  [0,540 1920x540]
        - Item2
      EOS
    end

    it "removes empty non-leaf nodes & merge nodes with same orientation" do
      desktop = Desktop::Widget.new
      create_n_views(desktop, 2)
      desktop.move(:top)
      create_n_views(desktop, 3)
      desktop.move(:right)
      desktop.focus(:left)
      desktop.move(:bottom)
      desktop.focus(:right)
      desktop.move(:left)
      desktop.to_yaml.strip.should eq(<<-EOS)
        ---
        Vertical:
        - LeafNode2:
          - Item3  [0,0 1920x360]
          - Item2
        - LeafNode4:
          - =Item5  [0,360 1920x360]
          - Item4
        - LeafNode1:
          - Item1  [0,720 1920x360]
        EOS
    end
  end
end
