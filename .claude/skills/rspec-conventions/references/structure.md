# Shaping a spec

How the file is laid out, how the groups nest, what the descriptions say.

Sources: **BS** = [betterspecs.org](https://www.betterspecs.org/), **SG** =
[rspec.rubystyle.guide](https://rspec.rubystyle.guide/). The snippets are as the
sources wrote them — single quotes, `FactoryBot`, `Article`; this repo uses
double quotes and has neither ActiveRecord nor FactoryBot. See
[README.md](README.md) for the other two files and for what was left out.

## Layout

### No blank line straight after a group opens — SG

```ruby
# bad
describe Article do

  describe '#summary' do

    context 'when there is a summary' do

      it 'returns the summary' do
        # ...
      end
    end
  end
end

# good
describe Article do
  describe '#summary' do
    context 'when there is a summary' do
      it 'returns the summary' do
        # ...
      end
    end
  end
end
```

### One blank line between groups, none before the closing `end` — SG

```ruby
# bad
describe Article do
  describe '#summary' do
    context 'when there is a summary' do
      # ...
    end
    context 'when there is no summary' do
      # ...
    end

  end
  describe '#comments' do
    # ...
  end
end

# good
describe Article do
  describe '#summary' do
    context 'when there is a summary' do
      # ...
    end

    context 'when there is no summary' do
      # ...
    end
  end

  describe '#comments' do
    # ...
  end
end
```

### Blank line after `let` / `subject`, and around examples — SG

```ruby
# bad
describe Article do
  subject { FactoryBot.create(:some_article) }
  describe '#summary' do
    # ...
  end
end

# good
describe Article do
  subject { FactoryBot.create(:some_article) }

  describe '#summary' do
    # ...
  end
end
```

```ruby
# bad
describe '#summary' do
  let(:item) { double('something') }

  it 'returns the summary' do
    # ...
  end
  it 'does something else' do
    # ...
  end
end

# good
describe '#summary' do
  let(:item) { double('something') }

  it 'returns the summary' do
    # ...
  end

  it 'does something else' do
    # ...
  end
end
```

### Declaration order: `subject`, `let`, hooks, nested groups — SG

`subject` and `let` sit together; the hooks are separated from them by a blank
line.

```ruby
# bad
describe Article do
  before do
    # ...
  end

  after do
    # ...
  end

  let(:user) { FactoryBot.create(:user) }
  subject { FactoryBot.create(:some_article) }

  describe '#summary' do
    # ...
  end
end

# good
describe Article do
  subject { FactoryBot.create(:some_article) }
  let(:user) { FactoryBot.create(:user) }

  before do
    # ...
  end

  after do
    # ...
  end

  describe '#summary' do
    # ...
  end
end
```

---

## Contexts

### Conditions belong in a context, not in the description — BS, SG

```ruby
# bad
it 'has 200 status code if logged in' do
  expect(response).to respond_with 200
end

it 'has 401 status code if not logged in' do
  expect(response).to respond_with 401
end

# good
context 'when logged in' do
  it { is_expected.to respond_with 200 }
end

context 'when logged out' do
  it { is_expected.to respond_with 401 }
end
```

```ruby
# bad
it 'returns the display name if it is present' do
  # ...
end

# good
context 'when display name is present' do
  it 'returns the display name' do
    # ...
  end
end

context 'when display name is not present' do
  it 'returns nil' do
    # ...
  end
end
```

### Start the description with `when` / `with` / `without` — SG

Nested descriptions have to concatenate into a sentence.

```ruby
# bad
describe 'Summary' do
  context 'user logged in' do
    context 'no display name' do
      it 'shows a placeholder' do
      end
    end
  end
end

# good
describe 'Summary' do
  context 'when the user is logged in' do
    context 'when the display name is blank' do
      it 'shows a placeholder' do
      end
    end
  end
end
```

### Give a context its opposite — SG

```ruby
# bad
describe '#attributes' do
  context 'when display name is present' do
    before do
      article.display_name = 'something'
    end

    it 'includes the display name' do
      # ...
    end
  end
end

# good
describe '#attributes' do
  subject(:attributes) { article.attributes }
  let(:article) { FactoryBot.create(:article) }

  context 'when display name is present' do
    before do
      article.display_name = 'something'
    end

    it { is_expected.to include(display_name: article.display_name) }
  end

  context 'when display name is not present' do
    before do
      article.display_name = nil
    end

    it { is_expected.not_to include(:display_name) }
  end
end
```

### Cover every case, not just the happy path — BS

```ruby
# bad
it 'shows the resource'

# good
describe '#destroy' do
  context 'when resource is found' do
    it 'responds with 200'
    it 'shows the resource'
  end

  context 'when resource is not found' do
    it 'responds with 404'
  end

  context 'when resource is not owned' do
    it 'responds with 404'
  end
end
```

---

## Naming

### `.class_method` and `#instance_method` — BS, SG

```ruby
# bad
describe 'the authenticate method for User' do
  # ...
end

describe 'if the user is an admin' do
  # ...
end

# good
describe '.authenticate' do
  # ...
end

describe '#admin?' do
  # ...
end
```

### No "should" — BS, SG

```ruby
# bad
it 'should return the summary' do
  # ...
end

it 'should not change timings' do
  consumption.occur_at.should == valid.occur_at
end

# good
it 'returns the summary' do
  # ...
end

it 'does not change timings' do
  expect(consumption.occur_at).to eq(valid.occur_at)
end
```

### Keep the description short — BS

Over ~40–60 characters usually means a context is missing.

```ruby
# bad
it 'has 422 status code if an unexpected params will be added' do

# good
context 'when not valid' do
  it { is_expected.to respond_with 422 }
end
```

### `it` when described, `specify` when not — SG

```ruby
# bad
it do
  # ...
end

specify 'it sends an email' do
  # ...
end

specify { is_expected.to be_truthy }

# good
specify do
  # ...
end

it 'sends an email' do
  # ...
end

it { is_expected.to be_truthy }
```
