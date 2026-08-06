# Asserting in a spec

How many expectations an example gets, and which matcher to reach for.

Sources: **BS** = [betterspecs.org](https://www.betterspecs.org/), **SG** =
[rspec.rubystyle.guide](https://rspec.rubystyle.guide/). The snippets are as the
sources wrote them — single quotes, `FactoryBot`, `Article`; this repo uses
double quotes and has neither ActiveRecord nor FactoryBot. See
[README.md](README.md) for the other two files and for what was left out.

## Expectations per example

One behaviour per example when the test is isolated. **In this repo that means
component and unit specs; system specs are exempt** — see SKILL.md.

```ruby
# good — isolated
it { is_expected.to respond_with_content_type(:json) }
it { is_expected.to assign_to(:resource) }
```

```ruby
# good — not isolated (DB, external service, end-to-end): repeating the setup
# costs more than the separation is worth
it 'creates a resource' do
  expect(response).to respond_with_content_type(:json)
  expect(response).to assign_to(:resource)
end
```

```ruby
# good — several expectations, made to report all their failures
describe 'GET new', :aggregate_failures do
  it 'assigns new article and renders the new article template' do
    get :new
    expect(assigns[:article]).to be_a(Article)
    expect(response).to render_template :new
  end
end
```

---

## Matchers

### `expect`, never `should` — BS, SG

```ruby
# bad
it 'creates a resource' do
  response.should respond_with_content_type(:json)
end

# good
it 'creates a resource' do
  expect(response).to respond_with_content_type(:json)
end
```

```ruby
# spec_helper.rb — so the old syntax cannot come back
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

### `is_expected` for one-liners — BS

```ruby
# bad
context 'when not valid' do
  it { should respond_with 422 }
end

# good
context 'when not valid' do
  it { is_expected.to respond_with 422 }
end
```

### Predicate matchers — SG

```ruby
# bad
it 'is published' do
  expect(article.published?).to be true
end

# good
it 'is published' do
  expect(article).to be_published
end

# better
it { is_expected.to be_published }
```

### Use the built-in matcher — SG

```ruby
# bad
it 'includes a title' do
  expect(article.title.include?('a lengthy title')).to be true
end

# good
it 'includes a title' do
  expect(article.title).to include 'a lengthy title'
end
```

### Never bare `be` — SG

```ruby
# bad
it 'has author' do
  expect(article.author).to be
end

# good
it 'has author' do
  expect(article.author).to be_truthy
  expect(article.author).not_to be_nil
  expect(article.author).to be_an(Author)
end
```

### Block expectations are written at the expectation — BS, SG

```ruby
# bad
lambda { model.save! }.to raise_error Mongoid::Errors::DocumentNotFound

# good
expect { model.save! }.to raise_error Mongoid::Errors::DocumentNotFound
```

```ruby
# bad
subject { -> { do_something } }
it { is_expected.to change(something).to(new_value) }

# good
it 'changes something to a new value' do
  expect { do_something }.to change(something).to(new_value)
end
```

### Extract a custom matcher when the assertion repeats — SG

```ruby
# bad
it 'returns JSON with temperature in Celsius' do
  json = JSON.parse(response.body).with_indifferent_access
  expect(json[:celsius]).to eq 30
end

it 'returns JSON with temperature in Fahrenheit' do
  json = JSON.parse(response.body).with_indifferent_access
  expect(json[:fahrenheit]).to eq 86
end

# good
it 'returns JSON with temperature in Celsius' do
  expect(response).to include_json(celsius: 30)
end

it 'returns JSON with temperature in Fahrenheit' do
  expect(response).to include_json(fahrenheit: 86)
end
```
