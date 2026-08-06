# Setting up a spec

Test data, subjects, hooks, shared state, and where to draw the line on doubles.

Sources: **BS** = [betterspecs.org](https://www.betterspecs.org/), **SG** =
[rspec.rubystyle.guide](https://rspec.rubystyle.guide/). The snippets are as the
sources wrote them — single quotes, `FactoryBot`, `Article`; this repo uses
double quotes and has neither ActiveRecord nor FactoryBot. See
[README.md](README.md) for the other two files and for what was left out.

## Data and setup

### `let` instead of instance variables — BS, SG

`let` is lazy and memoised per example — very nearly `def foo; @foo ||= Foo.new; end`.
Use `let!` when the thing must exist whether or not an example names it.

```ruby
# bad
before { @name = 'John Wayne' }

it 'reverses a name' do
  expect(reverser.reverse(@name)).to eq('enyaW nhoJ')
end

# good
let(:name) { 'John Wayne' }

it 'reverses a name' do
  expect(reverser.reverse(name)).to eq('enyaW nhoJ')
end
```

```ruby
# bad
describe '#type_id' do
  before { @resource = FactoryBot.create :device }
  before { @type = Type.find @resource.type_id }

  it 'sets the type_id field' do
    expect(@resource.type_id).to eq(@type.id)
  end
end

# good
describe '#type_id' do
  let(:resource) { FactoryBot.create :device }
  let(:type) { Type.find resource.type_id }

  it 'sets the type_id field' do
    expect(resource.type_id).to eq(type.id)
  end
end
```

### `let` to remove repetition between examples — SG

```ruby
# bad
it 'finds shortest path' do
  tree = Tree.new(1 => 2, 2 => 3, 2 => 6, 3 => 4, 4 => 5, 5 => 6)
  expect(dijkstra.shortest_path(tree, from: 1, to: 6)).to eq([1, 2, 6])
end

it 'finds longest path' do
  tree = Tree.new(1 => 2, 2 => 3, 2 => 6, 3 => 4, 4 => 5, 5 => 6)
  expect(dijkstra.longest_path(tree, from: 1, to: 6)).to eq([1, 2, 3, 4, 5, 6])
end

# good
let(:tree) { Tree.new(1 => 2, 2 => 3, 2 => 6, 3 => 4, 4 => 5, 5 => 6) }

it 'finds shortest path' do
  expect(dijkstra.shortest_path(tree, from: 1, to: 6)).to eq([1, 2, 6])
end

it 'finds longest path' do
  expect(dijkstra.longest_path(tree, from: 1, to: 6)).to eq([1, 2, 3, 4, 5, 6])
end
```

### Name the subject you refer to — SG

```ruby
# bad
it { expect(hero.equipment).to be_heavy }
it { expect(hero.equipment).to include 'sword' }

# good
subject(:equipment) { hero.equipment }

it { expect(equipment).to be_heavy }
it { expect(equipment).to include 'sword' }
```

```ruby
# bad
subject { FactoryBot.create(:article) }

it 'is not published on creation' do
  expect(subject).not_to be_published
end

# good — anonymous subject, referred to implicitly
subject { FactoryBot.create(:article) }

it 'is not published on creation' do
  is_expected.not_to be_published
end

# better — named, referred to by name
subject(:article) { FactoryBot.create(:article) }

it 'is not published on creation' do
  expect(article).not_to be_published
end
```

### Different subjects get different names — SG

```ruby
# bad
context 'when there is an author' do
  subject(:article) { FactoryBot.create(:article, author: user) }
  # ...
end

context 'when the author is anonymous' do
  subject(:article) { FactoryBot.create(:article, author: nil) }
  # ...
end

# good
context 'when article has an author' do
  subject(:article) { FactoryBot.create(:article, author: user) }
  # ...
end

context 'when the author is anonymous' do
  subject(:guest_article) { FactoryBot.create(:article, author: nil) }
  # ...
end
```

### Don't stub the object under test — SG

```ruby
# bad
subject(:article) { Article.new }

it 'indicates that the author is unknown' do
  allow(article).to receive(:author).and_return(nil)
  expect(article.description).to include('by an unknown author')
end

# good
subject(:article) { Article.new(author: nil) }

it 'indicates that the author is unknown' do
  expect(article.description).to include('by an unknown author')
end
```

### Hook scope — SG

`:each` is the default and adds nothing; `:all` is ambiguous, so write
`:context` — and prefer not to need it at all, since the state leaks.

```ruby
# bad
before(:example) do
  # ...
end

before(:all) do
  # ...
end

# good
before do
  # ...
end

before(:context) do
  # ...
end
```

### No incidental state — SG

```ruby
# bad
it 'publishes the article' do
  article.publish

  # Creating another shared Article test object above would cause this
  # test to break
  expect(Article.count).to eq(2)
end

# good
it 'publishes the article' do
  expect { article.publish }.to change(Article, :count).by(1)
end
```

### Constants and classes leak — SG

A `CONST = …` inside a `describe` block is defined on `Object`, not on the
example group.

```ruby
# bad
describe SomeClass do
  CONSTANT_HERE = 'I leak into global namespace'
end

# good
describe SomeClass do
  before do
    stub_const('CONSTANT_HERE', 'I only exist during this example')
  end
end
```

```ruby
# bad
describe SomeClass do
  class FooClass < described_class
    def double_that
      some_base_method * 2
    end
  end

  it { expect(FooClass.new.double_that).to eq(4) }
end

# good
describe SomeClass do
  let(:foo_class) do
    Class.new(described_class) do
      def double_that
        some_base_method * 2
      end
    end
  end

  it { expect(foo_class.new.double_that).to eq(4) }
end
```

### Shared examples for repeated behaviour — BS, SG

```ruby
# bad
describe 'GET /devices' do
  let!(:resource) { FactoryBot.create :device, created_from: user.id }
  let!(:uri) { '/devices' }

  context 'when shows all resources' do
    let!(:not_owned) { FactoryBot.create factory }

    it 'shows all owned resources' do
      page.driver.get uri
      expect(page.status_code).to be(200)
      contains_owned_resource resource
      does_not_contain_resource not_owned
    end
  end
end

# good
describe 'GET /devices' do
  let!(:resource) { FactoryBot.create :device, created_from: user.id }
  let!(:uri) { '/devices' }

  it_behaves_like 'a listable resource'
  it_behaves_like 'a paginable resource'
  it_behaves_like 'a searchable resource'
  it_behaves_like 'a filterable list'
end
```

```ruby
# good — defined next to the contexts that share it
describe 'GET /articles' do
  let(:article) { FactoryBot.create(:article, owner: owner) }

  before { page.driver.get '/articles' }

  shared_examples 'shows articles' do
    it 'shows all related articles' do
      expect(page.status_code).to be(200)
      contains_resource resource
    end
  end

  context 'when user is the owner' do
    let(:user) { owner }

    include_examples 'shows articles'
  end

  context 'when user is an admin' do
    let(:user) { FactoryBot.create(:user, :admin) }

    include_examples 'shows articles'
  end
end
```

---

## Doubles and stubs

### Mock the boundary, not the behaviour under test — BS

```ruby
# good
context 'when not found' do
  before do
    allow(Resource).to receive(:where).with(created_from: params[:id])
      .and_return(false)
  end

  it { is_expected.to respond_with 404 }
end
```

### Verifying doubles — SG

```ruby
# good
article = instance_double('Article')
allow(article).to receive(:author).and_return(nil)

presenter = described_class.new(article)
expect(presenter.title).to include('by an unknown author')
```

```ruby
# good — verifying partial double
allow(Article).to receive(:find).with(5).and_return(article)

# good — verifying class double
notifier = class_double('Notifier')
expect(notifier).to receive(:notify).with('suspended as')
```

### Never `allow_any_instance_of` — SG

```ruby
# bad
it 'has a name' do
  allow_any_instance_of(User).to receive(:name).and_return('Tweedledee')
  expect(account.name).to eq 'Tweedledee'
end

# good
let(:account) { Account.new(user) }

it 'has a name' do
  allow(user).to receive(:name).and_return('Tweedledee')
  expect(account.name).to eq 'Tweedledee'
end
```

### Stub outbound HTTP — BS

```ruby
# good
context 'with unauthorized access' do
  let(:uri) { 'http://api.lelylan.com/types' }

  before { stub_request(:get, uri).to_return(status: 401, body: fixture('401.json')) }

  it 'gets a not authorized notification' do
    page.driver.get uri
    expect(page).to have_content 'Access denied'
  end
end
```
