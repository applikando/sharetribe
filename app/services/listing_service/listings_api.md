
# listings/v1/

## GET /:community_id/search

Request params:

* keywords: "Search string"

Response:

```ruby
TODO
]
```

## GET /:community_id/count

Request params:

Same as above

* q: "Search string"
* category: "category_name"
* open: true/false

etc...

Response:

```ruby
123
```

## PUT /:community_id/

Request params:

* listing\_shape\_id: 123

Request body:

```ruby
{
  open: boolean
}
```
