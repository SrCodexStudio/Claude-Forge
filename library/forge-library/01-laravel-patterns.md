# Forge Library: Laravel Patterns

> Reference knowledge for building production-grade Laravel applications
> Read BEFORE writing controllers, models, services, or API endpoints

---

## Laravel 11+ Architecture

### Slim Skeleton & bootstrap/app.php

Laravel 11 removed most boilerplate files (Http/Kernel.php, many service providers, middleware classes).
All configuration now lives in `bootstrap/app.php`:

```php
<?php

declare(strict_types=1);

// bootstrap/app.php -- the single entry point for application configuration
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use App\Http\Middleware\EnsureJsonResponse;
use App\Http\Middleware\ForceHttps;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        health: '/up',                              // built-in health check
        apiPrefix: 'api/v1',                        // custom API prefix
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Global middleware (runs on every request)
        $middleware->prepend(ForceHttps::class);

        // API-specific middleware
        $middleware->api(prepend: [
            EnsureJsonResponse::class,
        ]);

        // Alias middleware for route-level use
        $middleware->alias([
            'admin' => \App\Http\Middleware\EnsureUserIsAdmin::class,
            'verified' => \App\Http\Middleware\EnsureEmailIsVerified::class,
        ]);

        // Throttle with named limiter
        $middleware->throttleApi('api');
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->renderable(function (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            return response()->json([
                'error' => 'Resource not found',
                'type' => 'not_found',
            ], 404);
        });

        $exceptions->renderable(function (\Illuminate\Validation\ValidationException $e) {
            return response()->json([
                'error' => 'Validation failed',
                'type' => 'validation_error',
                'details' => $e->errors(),
            ], 422);
        });
    })
    ->create();
```

### Route Registration (Laravel 11+)

```php
<?php

declare(strict_types=1);

// routes/api.php -- no Route::middleware('api') wrapper needed; applied automatically
use App\Http\Controllers\Api\UserController;
use App\Http\Controllers\Api\PostController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/register', [AuthController::class, 'register']);

// Authenticated routes
Route::middleware('auth:sanctum')->group(function (): void {
    Route::get('/me', [AuthController::class, 'me']);
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::apiResource('users', UserController::class);
    Route::apiResource('posts', PostController::class);

    // Admin-only routes
    Route::middleware('admin')->prefix('admin')->group(function (): void {
        Route::get('/stats', [AdminController::class, 'stats']);
    });
});
```

### When to Create a Service Provider

Laravel 11 ships with only `AppServiceProvider`. Create a new provider ONLY when:

1. You need to register complex bindings that would clutter AppServiceProvider.
2. You are building a package or module with its own boot logic.
3. You have deferred bindings (implements `DeferrableProvider`).

```php
<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\PaymentGateway;
use App\Services\StripePaymentGateway;
use Illuminate\Support\ServiceProvider;

/**
 * Register payment-related bindings.
 *
 * Created as a separate provider because payment wiring involves
 * multiple interfaces, config reads, and webhook registration.
 */
class PaymentServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(PaymentGateway::class, function ($app): StripePaymentGateway {
            return new StripePaymentGateway(
                apiKey: config('services.stripe.secret'),
                webhookSecret: config('services.stripe.webhook_secret'),
            );
        });
    }

    public function boot(): void
    {
        // Register webhook routes, publish config, etc.
    }
}
```

```php
// ANTI-PATTERN: do NOT create a provider for a single binding.
// Put simple bindings in AppServiceProvider::register() instead.
```

---

## Eloquent Best Practices

### Eager Loading (Preventing N+1)

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Resources\PostResource;
use App\Models\Post;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PostController extends Controller
{
    /**
     * List posts with related data.
     *
     * ANTI-PATTERN (N+1):
     *   $posts = Post::all();
     *   foreach ($posts as $post) {
     *       echo $post->author->name;    // 1 query per post
     *       echo $post->comments->count; // 1 query per post
     *   }
     *   // Total: 1 + N + N queries
     *
     * CORRECT: eager-load everything up front.
     */
    public function index(): AnonymousResourceCollection
    {
        $posts = Post::query()
            ->with(['author:id,name,avatar', 'tags:id,name'])  // select only needed columns
            ->withCount('comments')                             // adds comments_count attribute
            ->withSum('reactions', 'score')                     // adds reactions_sum_score
            ->latest()
            ->paginate(15);

        return PostResource::collection($posts);
    }

    /**
     * Lazy eager-load on an already-retrieved model.
     */
    public function show(Post $post): PostResource
    {
        $post->load(['author', 'comments.user']);
        $post->loadCount('reactions');

        return new PostResource($post);
    }
}
```

### Query Scopes

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class Post extends Model
{
    use SoftDeletes;

    protected $fillable = [
        'user_id',
        'title',
        'slug',
        'content',
        'status',
        'published_at',
    ];

    // --- Local scopes ---

    /**
     * Scope to only published posts.
     */
    public function scopePublished(Builder $query): Builder
    {
        return $query->where('status', 'published')
            ->whereNotNull('published_at')
            ->where('published_at', '<=', now());
    }

    /**
     * Scope with dynamic parameter.
     */
    public function scopeByAuthor(Builder $query, int $userId): Builder
    {
        return $query->where('user_id', $userId);
    }

    /**
     * Flexible filter scope -- accepts an associative array of optional filters.
     * Callers pass only the keys they care about.
     *
     * @param array<string, mixed> $filters
     */
    public function scopeFilter(Builder $query, array $filters): Builder
    {
        return $query
            ->when($filters['search'] ?? null, fn (Builder $q, string $search): Builder =>
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('content', 'like', "%{$search}%")
            )
            ->when($filters['status'] ?? null, fn (Builder $q, string $status): Builder =>
                $q->where('status', $status)
            )
            ->when($filters['author_id'] ?? null, fn (Builder $q, int $authorId): Builder =>
                $q->where('user_id', $authorId)
            )
            ->when($filters['tag'] ?? null, fn (Builder $q, string $tag): Builder =>
                $q->whereHas('tags', fn (Builder $tq): Builder =>
                    $tq->where('name', $tag)
                )
            );
    }
}
```

### Casts (Built-in, Custom, Enum)

```php
<?php

declare(strict_types=1);

namespace App\Models;

use App\Casts\EncryptedJson;
use App\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    protected $fillable = [
        'user_id',
        'status',
        'total_cents',
        'metadata',
        'billing_address',
        'shipped_at',
    ];

    /**
     * Attribute casting -- the modern way.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status'          => OrderStatus::class,       // backed enum cast
            'total_cents'     => 'integer',
            'metadata'        => 'array',                  // JSON column to array
            'billing_address' => EncryptedJson::class,     // custom cast
            'shipped_at'      => 'datetime',
            'is_priority'     => 'boolean',
        ];
    }

    // --- New-style Attribute accessors/mutators (Laravel 9+) ---

    /**
     * Get the total in dollars (derived from total_cents).
     */
    protected function totalDollars(): Attribute
    {
        return Attribute::make(
            get: fn (mixed $value, array $attributes): float =>
                round((int) $attributes['total_cents'] / 100, 2),
            set: fn (float $value): array =>
                ['total_cents' => (int) round($value * 100)],
        );
    }

    /**
     * Normalise the tracking number on write.
     */
    protected function trackingNumber(): Attribute
    {
        return Attribute::make(
            set: fn (?string $value): ?string =>
                $value !== null ? strtoupper(trim($value)) : null,
        );
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Enums;

/**
 * Backed enum for order status -- works directly as an Eloquent cast.
 */
enum OrderStatus: string
{
    case Pending   = 'pending';
    case Confirmed = 'confirmed';
    case Shipped   = 'shipped';
    case Delivered  = 'delivered';
    case Cancelled = 'cancelled';

    /**
     * Human-readable label.
     */
    public function label(): string
    {
        return match ($this) {
            self::Pending   => 'Pending',
            self::Confirmed => 'Confirmed',
            self::Shipped   => 'Shipped',
            self::Delivered  => 'Delivered',
            self::Cancelled => 'Cancelled',
        };
    }

    /**
     * Statuses considered "active" (not terminal).
     *
     * @return self[]
     */
    public static function active(): array
    {
        return [self::Pending, self::Confirmed, self::Shipped];
    }
}
```

### Custom Cast

```php
<?php

declare(strict_types=1);

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Crypt;

/**
 * Encrypts a JSON value at rest.
 *
 * @implements CastsAttributes<array<string, mixed>, array<string, mixed>>
 */
class EncryptedJson implements CastsAttributes
{
    /**
     * @param array<string, mixed> $attributes
     * @return array<string, mixed>
     */
    public function get(Model $model, string $key, mixed $value, array $attributes): array
    {
        if ($value === null) {
            return [];
        }

        $decrypted = Crypt::decryptString($value);

        return json_decode($decrypted, true, 512, JSON_THROW_ON_ERROR);
    }

    /**
     * @param array<string, mixed>|null $value
     * @param array<string, mixed> $attributes
     */
    public function set(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        if ($value === null) {
            return null;
        }

        $json = json_encode($value, JSON_THROW_ON_ERROR);

        return Crypt::encryptString($json);
    }
}
```

### Model Events vs Observers

```php
<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Article extends Model
{
    /**
     * Boot-time model events -- use for SIMPLE, self-contained side effects.
     * Prefer Observers when the logic grows or involves external services.
     */
    protected static function booted(): void
    {
        // Auto-generate slug on creation
        static::creating(function (Article $article): void {
            $article->slug = $article->slug ?: Str::slug($article->title);
        });

        // Cascade soft-delete comments when article is soft-deleted
        static::deleting(function (Article $article): void {
            if ($article->isForceDeleting()) {
                $article->comments()->forceDelete();
            } else {
                $article->comments()->delete();
            }
        });
    }
}
```

```php
<?php

declare(strict_types=1);

namespace App\Observers;

use App\Models\Order;
use App\Services\NotificationService;
use App\Services\InventoryService;

/**
 * Observer for complex multi-service side effects.
 * Registered in AppServiceProvider::boot().
 *
 * ANTI-PATTERN: putting this logic inside the model's booted() method.
 * Models should not know about notification or inventory services.
 */
class OrderObserver
{
    public function __construct(
        private readonly NotificationService $notifications,
        private readonly InventoryService $inventory,
    ) {}

    public function created(Order $order): void
    {
        $this->notifications->sendOrderConfirmation($order);
        $this->inventory->reserveItems($order);
    }

    public function updated(Order $order): void
    {
        if ($order->wasChanged('status') && $order->status->value === 'shipped') {
            $this->notifications->sendShippingNotification($order);
        }
    }
}
```

### Performance: Select, Chunking, Lazy Collections

```php
<?php

declare(strict_types=1);

// ANTI-PATTERN: loading every column and every row into memory
// $users = User::all(); // loads ALL columns of ALL rows

// CORRECT: select only needed columns
$users = User::query()
    ->select(['id', 'name', 'email', 'created_at'])
    ->where('status', 'active')
    ->get();

// CORRECT: chunk for batch processing (memory-safe)
User::query()
    ->where('last_login_at', '<', now()->subYear())
    ->chunkById(500, function ($users): void {
        foreach ($users as $user) {
            $user->update(['status' => 'inactive']);
        }
    });

// CORRECT: lazy collection for streaming large datasets
User::query()
    ->where('status', 'active')
    ->lazy(500)
    ->each(function (User $user): void {
        // Processes one chunk at a time, releasing memory after each
        dispatch(new SendNewsletterJob($user));
    });
```

---

## Form Requests

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Enums\OrderStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Enum;
use Illuminate\Validation\Rules\File;

/**
 * Validates and authorises requests to create an order.
 */
class StoreOrderRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return $this->user() !== null
            && $this->user()->can('create', \App\Models\Order::class);
    }

    /**
     * Validation rules.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Scalar fields
            'customer_email' => ['required', 'email:rfc,dns', 'max:255'],
            'status'         => ['sometimes', new Enum(OrderStatus::class)],
            'notes'          => ['nullable', 'string', 'max:2000'],
            'coupon_code'    => [
                'nullable',
                'string',
                Rule::exists('coupons', 'code')->where('active', true),
            ],

            // Nested array validation
            'items'              => ['required', 'array', 'min:1', 'max:50'],
            'items.*.product_id' => ['required', 'integer', Rule::exists('products', 'id')],
            'items.*.quantity'   => ['required', 'integer', 'min:1', 'max:100'],

            // Conditional validation
            'shipping_address'      => ['required_if:delivery_method,shipping', 'string'],
            'shipping_address.city' => ['required_with:shipping_address', 'string', 'max:100'],
            'shipping_address.zip'  => ['required_with:shipping_address', 'string', 'max:20'],

            // File validation
            'receipt' => [
                'nullable',
                File::types(['pdf', 'jpg', 'png'])
                    ->max(5 * 1024),   // 5 MB
            ],
        ];
    }

    /**
     * Custom error messages.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'items.required'              => 'At least one item is required.',
            'items.*.product_id.exists'   => 'Product #:input does not exist.',
            'items.*.quantity.max'        => 'Cannot order more than 100 of a single item.',
            'coupon_code.exists'          => 'This coupon is invalid or expired.',
        ];
    }

    /**
     * After-validation hook -- cross-field checks.
     */
    public function after(): array
    {
        return [
            function (\Illuminate\Validation\Validator $validator): void {
                $items = $this->input('items', []);
                $uniqueProducts = collect($items)->pluck('product_id')->unique();

                if ($uniqueProducts->count() !== count($items)) {
                    $validator->errors()->add(
                        'items',
                        'Duplicate products are not allowed. Increase quantity instead.',
                    );
                }
            },
        ];
    }

    /**
     * Prepare the data for validation.
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('customer_email')) {
            $this->merge([
                'customer_email' => strtolower(trim($this->input('customer_email'))),
            ]);
        }
    }
}
```

```php
// ANTI-PATTERN: validating inside the controller
public function store(Request $request)
{
    $request->validate([...]); // NO -- move to a FormRequest
    // ...
}
```

---

## API Resources

### Single Resource

```php
<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Post
 */
class PostResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'title'      => $this->title,
            'slug'       => $this->slug,
            'excerpt'    => $this->excerpt,
            'content'    => $this->when(
                $request->routeIs('posts.show'),   // include full content only on detail
                $this->content,
            ),
            'status'     => $this->status->value,
            'created_at' => $this->created_at->toIso8601String(),
            'updated_at' => $this->updated_at->toIso8601String(),

            // Conditional relations -- only serialised when eager-loaded
            'author'   => new UserResource($this->whenLoaded('author')),
            'tags'     => TagResource::collection($this->whenLoaded('tags')),
            'comments' => CommentResource::collection($this->whenLoaded('comments')),

            // Aggregates -- only present if loaded via withCount / withSum
            'comments_count'      => $this->whenCounted('comments'),
            'reactions_sum_score' => $this->whenAggregated('reactions', 'score', 'sum'),

            // Permission-gated fields
            'can_edit'   => $this->when(
                $request->user()?->can('update', $this->resource),
                true,
            ),
            'admin_note' => $this->when(
                $request->user()?->isAdmin(),
                $this->admin_note,
            ),
        ];
    }
}
```

### Collection Resource with Meta

```php
<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\ResourceCollection;

class PostCollection extends ResourceCollection
{
    /** @var string */
    public $collects = PostResource::class;

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'data' => $this->collection,
        ];
    }

    /**
     * Additional metadata included alongside the collection.
     *
     * @return array<string, mixed>
     */
    public function with(Request $request): array
    {
        return [
            'meta' => [
                'api_version' => 'v1',
                'generated_at' => now()->toIso8601String(),
            ],
        ];
    }
}
```

```php
// Usage in controller:
return new PostCollection(
    Post::query()
        ->with('author:id,name')
        ->withCount('comments')
        ->published()
        ->paginate(15)       // pagination meta is auto-merged
);
```

```php
// ANTI-PATTERN: returning raw models from controllers
public function index()
{
    return User::all(); // exposes every column, no transformation
}
```

---

## Service Pattern

### Thin Controller, Fat Service

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Requests\StoreOrderRequest;
use App\Http\Resources\OrderResource;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

/**
 * Controller stays thin -- delegates ALL business logic to the service.
 */
class OrderController extends Controller
{
    public function __construct(
        private readonly OrderService $orderService,
    ) {}

    public function store(StoreOrderRequest $request): JsonResponse
    {
        $order = $this->orderService->placeOrder(
            userId: $request->user()->id,
            items: $request->validated('items'),
            couponCode: $request->validated('coupon_code'),
            shippingAddress: $request->validated('shipping_address'),
        );

        return (new OrderResource($order))
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }
}
```

### Service Implementation

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Contracts\OrderRepositoryInterface;
use App\Events\OrderPlaced;
use App\Exceptions\InsufficientStockException;
use App\Models\Order;
use Illuminate\Support\Facades\DB;

/**
 * Encapsulates order creation business logic.
 *
 * Dependencies injected via constructor -- never instantiate services
 * with `new` inside controllers.
 */
class OrderService
{
    public function __construct(
        private readonly OrderRepositoryInterface $orders,
        private readonly InventoryService $inventory,
        private readonly CouponService $coupons,
    ) {}

    /**
     * Place a new order inside a database transaction.
     *
     * @param array<int, array{product_id: int, quantity: int}> $items
     * @param array<string, string>|null $shippingAddress
     *
     * @throws InsufficientStockException
     */
    public function placeOrder(
        int $userId,
        array $items,
        ?string $couponCode = null,
        ?array $shippingAddress = null,
    ): Order {
        return DB::transaction(function () use ($userId, $items, $couponCode, $shippingAddress): Order {
            // 1. Verify stock for every line item
            foreach ($items as $item) {
                $this->inventory->assertAvailable($item['product_id'], $item['quantity']);
            }

            // 2. Calculate total (apply coupon if provided)
            $subtotalCents = $this->inventory->calculateSubtotal($items);
            $discountCents = $couponCode
                ? $this->coupons->calculateDiscount($couponCode, $subtotalCents)
                : 0;

            // 3. Persist order
            $order = $this->orders->create([
                'user_id'          => $userId,
                'total_cents'      => $subtotalCents - $discountCents,
                'discount_cents'   => $discountCents,
                'shipping_address' => $shippingAddress,
            ]);

            // 4. Attach line items
            foreach ($items as $item) {
                $order->items()->create($item);
            }

            // 5. Decrement inventory
            $this->inventory->decrementStock($items);

            // 6. Fire domain event (listeners handle email, analytics, etc.)
            event(new OrderPlaced($order));

            return $order->load('items');
        });
    }
}
```

```php
// ANTI-PATTERN: business logic inside a controller
public function store(Request $request)
{
    DB::transaction(function () use ($request) {
        // 50+ lines of order logic directly in the controller
        // Impossible to unit-test, reuse, or maintain
    });
}
```

### Action Classes (Single-purpose Alternative)

```php
<?php

declare(strict_types=1);

namespace App\Actions;

use App\Models\User;
use Illuminate\Support\Facades\Hash;

/**
 * Action class: a service with exactly ONE public method.
 * Ideal when the operation is self-contained and unlikely to grow.
 */
class CreateUserAction
{
    /**
     * @param array{name: string, email: string, password: string} $data
     */
    public function execute(array $data): User
    {
        return User::create([
            'name'     => $data['name'],
            'email'    => $data['email'],
            'password' => Hash::make($data['password']),
        ]);
    }
}
```

---

## Repository Pattern

### Interface

```php
<?php

declare(strict_types=1);

namespace App\Contracts;

use Illuminate\Database\Eloquent\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

/**
 * Generic repository contract.
 *
 * @template T of \Illuminate\Database\Eloquent\Model
 */
interface RepositoryInterface
{
    public function findById(int $id): mixed;

    public function findOrFail(int $id): mixed;

    /**
     * @param array<string, mixed> $filters
     */
    public function paginate(array $filters = [], int $perPage = 15): LengthAwarePaginator;

    /**
     * @param array<string, mixed> $data
     */
    public function create(array $data): mixed;

    /**
     * @param array<string, mixed> $data
     */
    public function update(int $id, array $data): mixed;

    public function delete(int $id): bool;
}
```

### Eloquent Implementation

```php
<?php

declare(strict_types=1);

namespace App\Repositories;

use App\Contracts\OrderRepositoryInterface;
use App\Models\Order;
use Illuminate\Pagination\LengthAwarePaginator;

class EloquentOrderRepository implements OrderRepositoryInterface
{
    public function findById(int $id): ?Order
    {
        return Order::find($id);
    }

    public function findOrFail(int $id): Order
    {
        return Order::findOrFail($id);
    }

    /**
     * @param array<string, mixed> $filters
     */
    public function paginate(array $filters = [], int $perPage = 15): LengthAwarePaginator
    {
        return Order::query()
            ->with(['user:id,name', 'items.product'])
            ->withCount('items')
            ->filter($filters)          // uses the scope defined on the model
            ->latest()
            ->paginate($perPage);
    }

    /**
     * @param array<string, mixed> $data
     */
    public function create(array $data): Order
    {
        return Order::create($data);
    }

    /**
     * @param array<string, mixed> $data
     */
    public function update(int $id, array $data): Order
    {
        $order = $this->findOrFail($id);
        $order->update($data);

        return $order->fresh();
    }

    public function delete(int $id): bool
    {
        return (bool) Order::destroy($id);
    }

    /**
     * Domain-specific query: active orders for a user.
     *
     * @return \Illuminate\Database\Eloquent\Collection<int, Order>
     */
    public function findActiveByUser(int $userId): \Illuminate\Database\Eloquent\Collection
    {
        return Order::query()
            ->where('user_id', $userId)
            ->whereIn('status', \App\Enums\OrderStatus::active())
            ->with('items')
            ->get();
    }
}
```

### Provider Binding

```php
<?php

declare(strict_types=1);

// In AppServiceProvider::register()
$this->app->bind(
    \App\Contracts\OrderRepositoryInterface::class,
    \App\Repositories\EloquentOrderRepository::class,
);
```

### When to Skip the Repository Pattern

Skip repositories when:
- Your project is small (< 20 models) and will never change its ORM.
- You only perform simple CRUD -- Eloquent already IS the repository.
- Adding a repository would just proxy model calls without abstraction.

Use repositories when:
- You need to swap data sources (Eloquent today, API tomorrow).
- Complex query logic should live outside models and controllers.
- You want to unit-test services without touching the database.

---

## Event / Listener System

### Event Class

```php
<?php

declare(strict_types=1);

namespace App\Events;

use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Fired when a new order is successfully placed.
 * Broadcasts on a private channel so the frontend can update in real time.
 */
class OrderPlaced implements ShouldBroadcast
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(
        public readonly Order $order,
    ) {}

    /**
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('user.' . $this->order->user_id),
        ];
    }

    /**
     * Data sent to the frontend via WebSocket.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'order_id' => $this->order->id,
            'total'    => $this->order->total_cents,
            'status'   => $this->order->status->value,
        ];
    }
}
```

### Queued Listener

```php
<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Events\OrderPlaced;
use App\Mail\OrderConfirmationMail;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Mail;

/**
 * Sends an order confirmation email asynchronously.
 */
class SendOrderConfirmation implements ShouldQueue
{
    use InteractsWithQueue;

    /** @var string */
    public string $queue = 'emails';

    /** @var int */
    public int $tries = 3;

    /** @var int[] */
    public array $backoff = [10, 60, 300]; // seconds between retries

    public function handle(OrderPlaced $event): void
    {
        $order = $event->order->load('user', 'items.product');

        Mail::to($order->user->email)->send(
            new OrderConfirmationMail($order),
        );
    }

    /**
     * Called when all retries are exhausted.
     */
    public function failed(OrderPlaced $event, \Throwable $exception): void
    {
        \Log::error('Failed to send order confirmation', [
            'order_id' => $event->order->id,
            'error'    => $exception->getMessage(),
        ]);
    }
}
```

### Event-Listener Registration (Laravel 11+ auto-discovery)

```php
// Laravel 11 auto-discovers listeners. If you need manual mapping:

// AppServiceProvider::boot()
use Illuminate\Support\Facades\Event;

Event::listen(OrderPlaced::class, [
    SendOrderConfirmation::class,
    UpdateInventory::class,
    RecordAnalytics::class,
]);
```

### Event Subscriber

```php
<?php

declare(strict_types=1);

namespace App\Listeners;

use App\Events\OrderPlaced;
use App\Events\OrderShipped;
use App\Events\OrderCancelled;
use Illuminate\Events\Dispatcher;

/**
 * Groups related listeners for all order events.
 */
class OrderEventSubscriber
{
    public function handleOrderPlaced(OrderPlaced $event): void
    {
        // ...
    }

    public function handleOrderShipped(OrderShipped $event): void
    {
        // ...
    }

    public function handleOrderCancelled(OrderCancelled $event): void
    {
        // ...
    }

    /**
     * @return array<string, string>
     */
    public function subscribe(Dispatcher $events): array
    {
        return [
            OrderPlaced::class    => 'handleOrderPlaced',
            OrderShipped::class   => 'handleOrderShipped',
            OrderCancelled::class => 'handleOrderCancelled',
        ];
    }
}
```

---

## Queue Jobs

```php
<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Models\Order;
use App\Services\ShippingService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\Middleware\RateLimited;
use Illuminate\Queue\Middleware\WithoutOverlapping;
use Illuminate\Queue\SerializesModels;

/**
 * Processes an order for shipment.
 *
 * - ShouldBeUnique prevents duplicate dispatches for the same order.
 * - WithoutOverlapping prevents concurrent processing of the same order.
 * - RateLimited respects shipping API limits.
 */
class ProcessShipment implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    /** @var int Maximum attempts before permanent failure */
    public int $tries = 5;

    /** @var int[] Backoff intervals in seconds */
    public array $backoff = [30, 60, 120, 300, 600];

    /** @var int Timeout for a single execution attempt (seconds) */
    public int $timeout = 120;

    /** @var int Uniqueness window (seconds) */
    public int $uniqueFor = 3600;

    public function __construct(
        public readonly Order $order,
    ) {
        $this->onQueue('shipments');
    }

    /**
     * Unique ID prevents duplicate jobs for the same order.
     */
    public function uniqueId(): string
    {
        return 'shipment-' . $this->order->id;
    }

    /**
     * Job middleware.
     *
     * @return array<int, object>
     */
    public function middleware(): array
    {
        return [
            new WithoutOverlapping($this->order->id),
            new RateLimited('shipping-api'),
        ];
    }

    public function handle(ShippingService $shippingService): void
    {
        $tracking = $shippingService->createShipment($this->order);

        $this->order->update([
            'tracking_number' => $tracking->number,
            'shipped_at'      => now(),
            'status'          => 'shipped',
        ]);
    }

    /**
     * Called after all retries are exhausted.
     */
    public function failed(\Throwable $exception): void
    {
        \Log::error('Shipment processing failed permanently', [
            'order_id' => $this->order->id,
            'error'    => $exception->getMessage(),
        ]);

        $this->order->update(['status' => 'shipment_failed']);
    }
}
```

### Dispatch Strategies

```php
<?php

declare(strict_types=1);

use App\Jobs\ProcessShipment;
use App\Jobs\SendShippingNotification;
use App\Jobs\UpdateInventoryLedger;
use Illuminate\Support\Facades\Bus;

// --- Simple dispatch ---
ProcessShipment::dispatch($order);

// --- Delayed dispatch ---
ProcessShipment::dispatch($order)->delay(now()->addMinutes(5));

// --- Job chain (sequential, stops on failure) ---
Bus::chain([
    new ProcessShipment($order),
    new SendShippingNotification($order),
    new UpdateInventoryLedger($order),
])->dispatch();

// --- Job batch (parallel with callbacks) ---
Bus::batch([
    new ProcessShipment($orderA),
    new ProcessShipment($orderB),
    new ProcessShipment($orderC),
])
->then(function (\Illuminate\Bus\Batch $batch): void {
    \Log::info('All shipments processed', ['batch_id' => $batch->id]);
})
->catch(function (\Illuminate\Bus\Batch $batch, \Throwable $e): void {
    \Log::error('Batch shipment failed', ['error' => $e->getMessage()]);
})
->finally(function (\Illuminate\Bus\Batch $batch): void {
    // Runs regardless of success/failure
})
->onQueue('shipments')
->dispatch();
```

### Rate Limiter Definition (for job middleware)

```php
<?php

declare(strict_types=1);

// AppServiceProvider::boot()
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\RateLimiter;

RateLimiter::for('shipping-api', function (object $job): Limit {
    return Limit::perMinute(30);
});
```

---

## Sanctum Authentication

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

class AuthController extends Controller
{
    /**
     * Register a new user and return a token.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'name'     => $request->validated('name'),
            'email'    => $request->validated('email'),
            'password' => Hash::make($request->validated('password')),
        ]);

        $token = $user->createToken(
            name: 'api',
            abilities: ['read', 'write'],
            expiresAt: now()->addDays(30),
        )->plainTextToken;

        return response()->json([
            'user'  => new UserResource($user),
            'token' => $token,
        ], Response::HTTP_CREATED);
    }

    /**
     * Authenticate and issue a token.
     *
     * @throws ValidationException
     */
    public function login(LoginRequest $request): JsonResponse
    {
        if (! Auth::attempt($request->only('email', 'password'))) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        /** @var User $user */
        $user = Auth::user();

        // Revoke previous tokens for this device (optional)
        $user->tokens()
            ->where('name', 'api')
            ->delete();

        $token = $user->createToken(
            name: 'api',
            abilities: $this->resolveAbilities($user),
            expiresAt: now()->addDays(30),
        )->plainTextToken;

        return response()->json([
            'user'  => new UserResource($user),
            'token' => $token,
        ]);
    }

    /**
     * Return the authenticated user.
     */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user()->load('roles'));
    }

    /**
     * Revoke the current access token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out']);
    }

    /**
     * Map user role to token abilities.
     *
     * @return string[]
     */
    private function resolveAbilities(User $user): array
    {
        $base = ['read', 'write'];

        if ($user->isAdmin()) {
            return array_merge($base, ['admin:read', 'admin:write', 'users:manage']);
        }

        return $base;
    }
}
```

### Checking Abilities in Middleware

```php
<?php

declare(strict_types=1);

// routes/api.php
Route::middleware(['auth:sanctum', 'ability:admin:read'])->group(function (): void {
    Route::get('/admin/users', [AdminUserController::class, 'index']);
});

// Or check inside a controller:
public function destroy(Request $request, User $user): JsonResponse
{
    if (! $request->user()->tokenCan('users:manage')) {
        abort(403, 'Insufficient permissions');
    }

    $user->delete();

    return response()->json(status: Response::HTTP_NO_CONTENT);
}
```

```php
// ANTI-PATTERN: not revoking old tokens, leading to token sprawl
public function login(Request $request)
{
    // Creates new token every login without revoking old ones
    return $request->user()->createToken('api')->plainTextToken;
}
```

---

## Rate Limiting

```php
<?php

declare(strict_types=1);

// AppServiceProvider::boot() or bootstrap/app.php

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

// Default API limiter (Laravel 11+: per-second support)
RateLimiter::for('api', function (Request $request): Limit {
    return $request->user()
        ? Limit::perMinute(120)->by($request->user()->id)
        : Limit::perMinute(30)->by($request->ip());
});

// Per-second limiter (Laravel 11+)
RateLimiter::for('uploads', function (Request $request): Limit {
    return Limit::perSecond(2)->by($request->user()?->id ?: $request->ip());
});

// Tiered limiter based on subscription
RateLimiter::for('search', function (Request $request): Limit {
    $user = $request->user();

    if ($user?->isOnPlan('enterprise')) {
        return Limit::none();                             // unlimited
    }

    if ($user?->isOnPlan('pro')) {
        return Limit::perMinute(60)->by($user->id);
    }

    return Limit::perMinute(10)->by($request->ip());
});

// Multiple limits on a single endpoint
RateLimiter::for('login', function (Request $request): array {
    return [
        Limit::perMinute(5)->by($request->input('email')),  // per email
        Limit::perMinute(30)->by($request->ip()),            // per IP
    ];
});
```

### Applying to Routes

```php
<?php

declare(strict_types=1);

// routes/api.php
Route::middleware('throttle:api')->group(function (): void {
    // All API routes use the 'api' limiter
});

Route::middleware('throttle:uploads')->group(function (): void {
    Route::post('/files', [FileController::class, 'store']);
});

Route::middleware('throttle:login')->post('/auth/login', [AuthController::class, 'login']);
```

---

## Caching Strategies

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Post;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Collection;
use Illuminate\Pagination\LengthAwarePaginator;

class PostService
{
    /**
     * Cache::remember -- the workhorse pattern.
     * Fetches from cache if available; otherwise runs the closure and stores the result.
     *
     * @return Collection<int, Post>
     */
    public function getFeaturedPosts(): Collection
    {
        return Cache::remember(
            key: 'posts:featured',
            ttl: now()->addHours(1),
            callback: fn (): Collection => Post::query()
                ->published()
                ->where('is_featured', true)
                ->with('author:id,name')
                ->orderByDesc('published_at')
                ->limit(10)
                ->get(),
        );
    }

    /**
     * Tag-based caching for granular invalidation.
     * All post-related caches share the 'posts' tag.
     */
    public function getPostBySlug(string $slug): ?Post
    {
        return Cache::tags(['posts'])->remember(
            key: "post:slug:{$slug}",
            ttl: now()->addMinutes(30),
            callback: fn (): ?Post => Post::query()
                ->where('slug', $slug)
                ->with(['author', 'tags', 'comments.user'])
                ->first(),
        );
    }

    /**
     * Cache a paginated result (careful: include page number in the key).
     *
     * @param array<string, mixed> $filters
     */
    public function listPosts(array $filters, int $page = 1): LengthAwarePaginator
    {
        $cacheKey = 'posts:list:' . md5(json_encode($filters) . ":page:{$page}");

        return Cache::tags(['posts'])->remember(
            key: $cacheKey,
            ttl: now()->addMinutes(10),
            callback: fn (): LengthAwarePaginator => Post::query()
                ->with('author:id,name')
                ->withCount('comments')
                ->filter($filters)
                ->latest()
                ->paginate(15, ['*'], 'page', $page),
        );
    }

    /**
     * Invalidate all post caches when a post is created/updated/deleted.
     * Call this from an observer or event listener.
     */
    public function clearPostCache(?string $slug = null): void
    {
        // Flush everything under the 'posts' tag
        Cache::tags(['posts'])->flush();

        // Also remove the featured cache (not tagged)
        Cache::forget('posts:featured');
    }
}
```

### Model-level Cache via Observer

```php
<?php

declare(strict_types=1);

namespace App\Observers;

use App\Models\Post;
use App\Services\PostService;

class PostCacheObserver
{
    public function __construct(
        private readonly PostService $postService,
    ) {}

    public function saved(Post $post): void
    {
        $this->postService->clearPostCache($post->slug);
    }

    public function deleted(Post $post): void
    {
        $this->postService->clearPostCache($post->slug);
    }
}
```

### Redis vs File Driver

```php
// ANTI-PATTERN: relying on file cache in production with tag support
// File driver does NOT support Cache::tags(). Use Redis or Memcached.

// .env
// CACHE_STORE=redis          # production
// CACHE_STORE=file           # local development (no tags)
// CACHE_STORE=array          # testing (ephemeral, per-request)

// config/cache.php should read CACHE_STORE from env without inline defaults.
```

### Cache Warming

```php
<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\PostService;
use Illuminate\Console\Command;

/**
 * Warm frequently-accessed caches on deploy or via scheduler.
 *
 * Schedule: $schedule->command('cache:warm')->hourly();
 */
class WarmCacheCommand extends Command
{
    protected $signature = 'cache:warm';
    protected $description = 'Pre-warm application caches';

    public function handle(PostService $postService): int
    {
        $this->info('Warming featured posts cache...');
        $postService->getFeaturedPosts();

        $this->info('Warming popular post caches...');
        $slugs = \App\Models\Post::query()
            ->published()
            ->orderByDesc('views')
            ->limit(50)
            ->pluck('slug');

        foreach ($slugs as $slug) {
            $postService->getPostBySlug($slug);
        }

        $this->info('Cache warmed successfully.');

        return self::SUCCESS;
    }
}
```

---

## Quick Reference: Anti-Pattern Summary

| Category | Anti-Pattern | Correct Approach |
|----------|-------------|-----------------|
| **N+1** | `Post::all()` then `$post->author` in loop | `Post::with('author')->get()` |
| **Validation** | `$request->validate([...])` in controller | Dedicated `FormRequest` class |
| **Response** | `return User::all()` raw model | `UserResource::collection(...)` |
| **Business logic** | 50+ lines in controller method | Extract to `Service` or `Action` class |
| **Secrets** | `env('KEY', 'fallback')` in code | `config('services.key')` reading from `.env` |
| **Caching** | Forget to bust cache on writes | Observer or event listener calls `Cache::forget()` |
| **Queues** | No retry / no `failed()` handler | Set `$tries`, `$backoff`, implement `failed()` |
| **Auth tokens** | Never revoking old tokens | Delete previous tokens on new login |
| **Mass assignment** | No `$fillable` or `$guarded` | Always define `$fillable` explicitly |
| **Raw queries** | `DB::select("...WHERE x = '$input'")` | `DB::select('...WHERE x = ?', [$input])` |
| **Eager loading** | Loading all columns with `*` | `->select(['id', 'name'])` or `with('rel:id,name')` |
| **File cache + tags** | `Cache::tags([...])` with file driver | Use Redis or Memcached for tag support |

---

## Directory Structure Summary

```
app/
  Actions/            -- Single-purpose action classes
  Contracts/          -- Interfaces (repositories, services)
  Enums/              -- Backed enums for type-safe constants
  Events/             -- Domain events
  Exceptions/         -- Custom exception classes
  Http/
    Controllers/      -- Thin controllers (max 7 methods each)
    Middleware/        -- Request/response filters
    Requests/          -- FormRequest validation classes
    Resources/         -- API resource transformers
  Jobs/               -- Queueable background jobs
  Listeners/          -- Event listeners / subscribers
  Mail/               -- Mailable classes
  Models/             -- Eloquent models with scopes, casts, relations
  Observers/          -- Model lifecycle observers
  Policies/           -- Authorization policies
  Repositories/       -- Data access layer implementations
  Services/           -- Business logic services
bootstrap/
  app.php             -- Application wiring (Laravel 11+ single file)
config/               -- Config files reading from .env
database/
  migrations/         -- Timestamped schema migrations
  seeders/            -- Test/seed data
  factories/          -- Model factories for testing
routes/
  api.php             -- API routes (auto-prefixed, throttled)
  web.php             -- Web routes (session, CSRF)
  console.php         -- Artisan command schedules
tests/
  Feature/            -- HTTP integration tests
  Unit/               -- Isolated unit tests
```
