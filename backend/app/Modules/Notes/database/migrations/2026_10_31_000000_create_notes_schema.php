<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public');
        DB::statement('CREATE SCHEMA IF NOT EXISTS notes');
        DB::statement(<<<'SQL'
            CREATE OR REPLACE FUNCTION notes.immutable_unaccent(text) RETURNS text
            LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
            AS $$ SELECT public.unaccent('public.unaccent'::regdictionary, $1) $$
            SQL);

        Schema::create('notes.note_folders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('parent_id')->nullable();
            $table->text('name');
            $table->integer('position')->default(0);
            $table->timestampsTz(6);

            $table->index(['user_id', 'parent_id']);
        });
        Schema::table('notes.note_folders', function (Blueprint $table) {
            $table->foreign('parent_id')->references('id')->on('notes.note_folders');
        });

        Schema::create('notes.notes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('folder_id')->nullable()->constrained('notes.note_folders')->nullOnDelete();
            $table->text('type');
            $table->text('title')->nullable();
            $table->text('body')->nullable();
            $table->timestampTz('pinned_at', 6)->nullable();
            $table->timestampTz('archived_at', 6)->nullable();
            $table->timestampTz('deleted_at', 6)->nullable();
            $table->text('checked_behavior')->default('move');
            $table->boolean('is_primary')->default(false);
            $table->integer('sort')->default(0);
            $table->timestampsTz(6);

            $table->index(['user_id', 'folder_id']);
        });
        DB::statement("ALTER TABLE notes.notes ADD CONSTRAINT notes_type_check CHECK (type IN ('text','list','shopping'))");
        DB::statement("ALTER TABLE notes.notes ADD CONSTRAINT notes_checked_behavior_check CHECK (checked_behavior IN ('move','inline'))");
        DB::statement("ALTER TABLE notes.notes ADD CONSTRAINT notes_primary_shopping_check CHECK (NOT is_primary OR type = 'shopping')");
        DB::statement("ALTER TABLE notes.notes ADD COLUMN search tsvector GENERATED ALWAYS AS (to_tsvector('spanish', notes.immutable_unaccent(coalesce(title, '') || ' ' || coalesce(body, '')))) STORED");
        DB::statement('CREATE INDEX notes_search_index ON notes.notes USING gin (search)');
        DB::statement('CREATE UNIQUE INDEX notes_primary_shopping_unique ON notes.notes (user_id) WHERE is_primary');

        Schema::create('notes.shopping_sections', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('name');
            $table->integer('position')->default(0);
            $table->timestampsTz(6);

            $table->index(['user_id', 'position']);
        });

        Schema::create('notes.shopping_products', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('note_id')->constrained('notes.notes')->cascadeOnDelete();
            $table->text('name');
            $table->text('name_normalized');
            $table->foreignUuid('section_id')->nullable()->constrained('notes.shopping_sections')->nullOnDelete();
            $table->text('default_quantity')->nullable();
            $table->text('restock_mode')->default('none');
            $table->integer('restock_interval_days')->nullable();
            $table->timestampTz('last_bought_at', 6)->nullable();
            $table->integer('times_bought')->default(0);
            $table->text('restocked_for')->nullable();
            $table->timestampsTz(6);

            $table->index(['note_id', 'name_normalized']);
            $table->index('user_id');
        });
        DB::statement("ALTER TABLE notes.shopping_products ADD CONSTRAINT shopping_products_restock_mode_check CHECK (restock_mode IN ('every_trip','interval','none'))");
        DB::statement('ALTER TABLE notes.shopping_products ADD CONSTRAINT shopping_products_restock_interval_days_check CHECK (restock_interval_days IS NULL OR restock_interval_days >= 1)');

        Schema::create('notes.note_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('note_id')->constrained('notes.notes')->cascadeOnDelete();
            $table->foreignUuid('product_id')->nullable()->constrained('notes.shopping_products')->nullOnDelete();
            $table->text('text');
            $table->text('quantity')->nullable();
            $table->foreignUuid('section_id')->nullable()->constrained('notes.shopping_sections')->nullOnDelete();
            $table->timestampTz('checked_at', 6)->nullable();
            $table->integer('position')->default(0);
            $table->timestampsTz(6);

            $table->index(['note_id', 'position']);
            $table->index('product_id');
        });
        DB::statement("ALTER TABLE notes.note_items ADD COLUMN search tsvector GENERATED ALWAYS AS (to_tsvector('spanish', notes.immutable_unaccent(text))) STORED");
        DB::statement('CREATE INDEX note_items_search_index ON notes.note_items USING gin (search)');

        Schema::create('notes.sync_operations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('type');
            $table->timestampTz('processed_at', 6);
            $table->text('status');

            $table->index(['user_id', 'processed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notes.sync_operations');
        Schema::dropIfExists('notes.note_items');
        Schema::dropIfExists('notes.shopping_products');
        Schema::dropIfExists('notes.shopping_sections');
        Schema::dropIfExists('notes.notes');
        Schema::dropIfExists('notes.note_folders');
        DB::statement('DROP FUNCTION IF EXISTS notes.immutable_unaccent(text)');
        DB::statement('DROP SCHEMA IF EXISTS notes');
    }
};
