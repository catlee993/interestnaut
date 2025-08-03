// This is a generated file - do not edit.
//
// Generated from recommendation.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Request for personalized recommendations
class RecommendationRequest extends $pb.GeneratedMessage {
  factory RecommendationRequest({
    $core.String? mediaType,
    $core.String? userQuery,
    $core.Iterable<$core.String>? likedMediaIds,
    $core.Iterable<$core.String>? favoritedMediaIds,
    $core.Iterable<$core.String>? watchlistMediaIds,
    $core.Iterable<$core.String>? dislikedMediaIds,
    $core.Iterable<$core.String>? skippedMediaIds,
    $core.Iterable<$core.String>? excludeMediaIds,
    $core.Iterable<$core.String>? constraints,
    $core.int? limit,
    $core.bool? useBehavioralMatching,
    $core.double? similarityThreshold,
    $core.int? attributesToMatch,
    $core.Iterable<$core.String>? priorityTitleIds,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (userQuery != null) result.userQuery = userQuery;
    if (likedMediaIds != null) result.likedMediaIds.addAll(likedMediaIds);
    if (favoritedMediaIds != null)
      result.favoritedMediaIds.addAll(favoritedMediaIds);
    if (watchlistMediaIds != null)
      result.watchlistMediaIds.addAll(watchlistMediaIds);
    if (dislikedMediaIds != null)
      result.dislikedMediaIds.addAll(dislikedMediaIds);
    if (skippedMediaIds != null) result.skippedMediaIds.addAll(skippedMediaIds);
    if (excludeMediaIds != null) result.excludeMediaIds.addAll(excludeMediaIds);
    if (constraints != null) result.constraints.addAll(constraints);
    if (limit != null) result.limit = limit;
    if (useBehavioralMatching != null)
      result.useBehavioralMatching = useBehavioralMatching;
    if (similarityThreshold != null)
      result.similarityThreshold = similarityThreshold;
    if (attributesToMatch != null) result.attributesToMatch = attributesToMatch;
    if (priorityTitleIds != null)
      result.priorityTitleIds.addAll(priorityTitleIds);
    return result;
  }

  RecommendationRequest._();

  factory RecommendationRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecommendationRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecommendationRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..aOS(2, _omitFieldNames ? '' : 'userQuery')
    ..pPS(3, _omitFieldNames ? '' : 'likedMediaIds')
    ..pPS(4, _omitFieldNames ? '' : 'favoritedMediaIds')
    ..pPS(5, _omitFieldNames ? '' : 'watchlistMediaIds')
    ..pPS(6, _omitFieldNames ? '' : 'dislikedMediaIds')
    ..pPS(7, _omitFieldNames ? '' : 'skippedMediaIds')
    ..pPS(8, _omitFieldNames ? '' : 'excludeMediaIds')
    ..pPS(9, _omitFieldNames ? '' : 'constraints')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..aOB(11, _omitFieldNames ? '' : 'useBehavioralMatching')
    ..a<$core.double>(
        12, _omitFieldNames ? '' : 'similarityThreshold', $pb.PbFieldType.OD)
    ..a<$core.int>(
        13, _omitFieldNames ? '' : 'attributesToMatch', $pb.PbFieldType.O3)
    ..pPS(14, _omitFieldNames ? '' : 'priorityTitleIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationRequest clone() =>
      RecommendationRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationRequest copyWith(
          void Function(RecommendationRequest) updates) =>
      super.copyWith((message) => updates(message as RecommendationRequest))
          as RecommendationRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecommendationRequest create() => RecommendationRequest._();
  @$core.override
  RecommendationRequest createEmptyInstance() => create();
  static $pb.PbList<RecommendationRequest> createRepeated() =>
      $pb.PbList<RecommendationRequest>();
  @$core.pragma('dart2js:noInline')
  static RecommendationRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecommendationRequest>(create);
  static RecommendationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userQuery => $_getSZ(1);
  @$pb.TagNumber(2)
  set userQuery($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserQuery() => $_clearField(2);

  /// User behavior signals from local database
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get likedMediaIds => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get favoritedMediaIds => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get watchlistMediaIds => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get dislikedMediaIds => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get skippedMediaIds => $_getList(6);

  /// Exclusions to prevent re-suggesting
  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get excludeMediaIds => $_getList(7);

  /// Constraints and preferences
  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get constraints => $_getList(8);

  @$pb.TagNumber(10)
  $core.int get limit => $_getIZ(9);
  @$pb.TagNumber(10)
  set limit($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLimit() => $_has(9);
  @$pb.TagNumber(10)
  void clearLimit() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get useBehavioralMatching => $_getBF(10);
  @$pb.TagNumber(11)
  set useBehavioralMatching($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasUseBehavioralMatching() => $_has(10);
  @$pb.TagNumber(11)
  void clearUseBehavioralMatching() => $_clearField(11);

  /// Matching parameters
  @$pb.TagNumber(12)
  $core.double get similarityThreshold => $_getN(11);
  @$pb.TagNumber(12)
  set similarityThreshold($core.double value) => $_setDouble(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSimilarityThreshold() => $_has(11);
  @$pb.TagNumber(12)
  void clearSimilarityThreshold() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get attributesToMatch => $_getIZ(12);
  @$pb.TagNumber(13)
  set attributesToMatch($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAttributesToMatch() => $_has(12);
  @$pb.TagNumber(13)
  void clearAttributesToMatch() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<$core.String> get priorityTitleIds => $_getList(13);
}

class RecommendationResponse extends $pb.GeneratedMessage {
  factory RecommendationResponse({
    $core.Iterable<MediaItem>? recommendations,
    $core.String? error,
    RecommendationMetadata? metadata,
  }) {
    final result = create();
    if (recommendations != null) result.recommendations.addAll(recommendations);
    if (error != null) result.error = error;
    if (metadata != null) result.metadata = metadata;
    return result;
  }

  RecommendationResponse._();

  factory RecommendationResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecommendationResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecommendationResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pc<MediaItem>(
        1, _omitFieldNames ? '' : 'recommendations', $pb.PbFieldType.PM,
        subBuilder: MediaItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..aOM<RecommendationMetadata>(3, _omitFieldNames ? '' : 'metadata',
        subBuilder: RecommendationMetadata.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationResponse clone() =>
      RecommendationResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationResponse copyWith(
          void Function(RecommendationResponse) updates) =>
      super.copyWith((message) => updates(message as RecommendationResponse))
          as RecommendationResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecommendationResponse create() => RecommendationResponse._();
  @$core.override
  RecommendationResponse createEmptyInstance() => create();
  static $pb.PbList<RecommendationResponse> createRepeated() =>
      $pb.PbList<RecommendationResponse>();
  @$core.pragma('dart2js:noInline')
  static RecommendationResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecommendationResponse>(create);
  static RecommendationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get recommendations => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);

  @$pb.TagNumber(3)
  RecommendationMetadata get metadata => $_getN(2);
  @$pb.TagNumber(3)
  set metadata(RecommendationMetadata value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMetadata() => $_has(2);
  @$pb.TagNumber(3)
  void clearMetadata() => $_clearField(3);
  @$pb.TagNumber(3)
  RecommendationMetadata ensureMetadata() => $_ensure(2);
}

class RecommendationMetadata extends $pb.GeneratedMessage {
  factory RecommendationMetadata({
    $core.String? algorithmUsed,
    $core.int? totalCandidates,
    $core.double? processingTimeMs,
  }) {
    final result = create();
    if (algorithmUsed != null) result.algorithmUsed = algorithmUsed;
    if (totalCandidates != null) result.totalCandidates = totalCandidates;
    if (processingTimeMs != null) result.processingTimeMs = processingTimeMs;
    return result;
  }

  RecommendationMetadata._();

  factory RecommendationMetadata.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecommendationMetadata.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecommendationMetadata',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'algorithmUsed')
    ..a<$core.int>(
        2, _omitFieldNames ? '' : 'totalCandidates', $pb.PbFieldType.O3)
    ..a<$core.double>(
        3, _omitFieldNames ? '' : 'processingTimeMs', $pb.PbFieldType.OD)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationMetadata clone() =>
      RecommendationMetadata()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecommendationMetadata copyWith(
          void Function(RecommendationMetadata) updates) =>
      super.copyWith((message) => updates(message as RecommendationMetadata))
          as RecommendationMetadata;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecommendationMetadata create() => RecommendationMetadata._();
  @$core.override
  RecommendationMetadata createEmptyInstance() => create();
  static $pb.PbList<RecommendationMetadata> createRepeated() =>
      $pb.PbList<RecommendationMetadata>();
  @$core.pragma('dart2js:noInline')
  static RecommendationMetadata getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecommendationMetadata>(create);
  static RecommendationMetadata? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get algorithmUsed => $_getSZ(0);
  @$pb.TagNumber(1)
  set algorithmUsed($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAlgorithmUsed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAlgorithmUsed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalCandidates => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCandidates($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCandidates() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCandidates() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get processingTimeMs => $_getN(2);
  @$pb.TagNumber(3)
  set processingTimeMs($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProcessingTimeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearProcessingTimeMs() => $_clearField(3);
}

/// Request for similar items
class SimilarItemsRequest extends $pb.GeneratedMessage {
  factory SimilarItemsRequest({
    $core.String? referenceMediaId,
    $core.String? mediaType,
    $core.Iterable<$core.String>? excludeMediaIds,
    $core.int? limit,
  }) {
    final result = create();
    if (referenceMediaId != null) result.referenceMediaId = referenceMediaId;
    if (mediaType != null) result.mediaType = mediaType;
    if (excludeMediaIds != null) result.excludeMediaIds.addAll(excludeMediaIds);
    if (limit != null) result.limit = limit;
    return result;
  }

  SimilarItemsRequest._();

  factory SimilarItemsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimilarItemsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimilarItemsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'referenceMediaId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaType')
    ..pPS(3, _omitFieldNames ? '' : 'excludeMediaIds')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimilarItemsRequest clone() => SimilarItemsRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimilarItemsRequest copyWith(void Function(SimilarItemsRequest) updates) =>
      super.copyWith((message) => updates(message as SimilarItemsRequest))
          as SimilarItemsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimilarItemsRequest create() => SimilarItemsRequest._();
  @$core.override
  SimilarItemsRequest createEmptyInstance() => create();
  static $pb.PbList<SimilarItemsRequest> createRepeated() =>
      $pb.PbList<SimilarItemsRequest>();
  @$core.pragma('dart2js:noInline')
  static SimilarItemsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimilarItemsRequest>(create);
  static SimilarItemsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get referenceMediaId => $_getSZ(0);
  @$pb.TagNumber(1)
  set referenceMediaId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReferenceMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReferenceMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaType() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get excludeMediaIds => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);
}

class SimilarItemsResponse extends $pb.GeneratedMessage {
  factory SimilarItemsResponse({
    $core.Iterable<MediaItem>? similarItems,
    $core.String? error,
  }) {
    final result = create();
    if (similarItems != null) result.similarItems.addAll(similarItems);
    if (error != null) result.error = error;
    return result;
  }

  SimilarItemsResponse._();

  factory SimilarItemsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SimilarItemsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SimilarItemsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pc<MediaItem>(
        1, _omitFieldNames ? '' : 'similarItems', $pb.PbFieldType.PM,
        subBuilder: MediaItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimilarItemsResponse clone() =>
      SimilarItemsResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SimilarItemsResponse copyWith(void Function(SimilarItemsResponse) updates) =>
      super.copyWith((message) => updates(message as SimilarItemsResponse))
          as SimilarItemsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SimilarItemsResponse create() => SimilarItemsResponse._();
  @$core.override
  SimilarItemsResponse createEmptyInstance() => create();
  static $pb.PbList<SimilarItemsResponse> createRepeated() =>
      $pb.PbList<SimilarItemsResponse>();
  @$core.pragma('dart2js:noInline')
  static SimilarItemsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SimilarItemsResponse>(create);
  static SimilarItemsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get similarItems => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Search request with constraints
class SearchRequest extends $pb.GeneratedMessage {
  factory SearchRequest({
    $core.String? mediaType,
    $core.Iterable<$core.String>? constraints,
    $core.Iterable<$core.String>? excludeMediaIds,
    $core.int? limit,
    $core.int? offset,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (constraints != null) result.constraints.addAll(constraints);
    if (excludeMediaIds != null) result.excludeMediaIds.addAll(excludeMediaIds);
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    return result;
  }

  SearchRequest._();

  factory SearchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..pPS(2, _omitFieldNames ? '' : 'constraints')
    ..pPS(3, _omitFieldNames ? '' : 'excludeMediaIds')
    ..a<$core.int>(4, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'offset', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest clone() => SearchRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest copyWith(void Function(SearchRequest) updates) =>
      super.copyWith((message) => updates(message as SearchRequest))
          as SearchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchRequest create() => SearchRequest._();
  @$core.override
  SearchRequest createEmptyInstance() => create();
  static $pb.PbList<SearchRequest> createRepeated() =>
      $pb.PbList<SearchRequest>();
  @$core.pragma('dart2js:noInline')
  static SearchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchRequest>(create);
  static SearchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get constraints => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get excludeMediaIds => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get offset => $_getIZ(4);
  @$pb.TagNumber(5)
  set offset($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOffset() => $_has(4);
  @$pb.TagNumber(5)
  void clearOffset() => $_clearField(5);
}

class SearchResponse extends $pb.GeneratedMessage {
  factory SearchResponse({
    $core.Iterable<MediaItem>? results,
    $core.String? error,
    $core.int? totalCount,
  }) {
    final result = create();
    if (results != null) result.results.addAll(results);
    if (error != null) result.error = error;
    if (totalCount != null) result.totalCount = totalCount;
    return result;
  }

  SearchResponse._();

  factory SearchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pc<MediaItem>(1, _omitFieldNames ? '' : 'results', $pb.PbFieldType.PM,
        subBuilder: MediaItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'totalCount', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse clone() => SearchResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse copyWith(void Function(SearchResponse) updates) =>
      super.copyWith((message) => updates(message as SearchResponse))
          as SearchResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchResponse create() => SearchResponse._();
  @$core.override
  SearchResponse createEmptyInstance() => create();
  static $pb.PbList<SearchResponse> createRepeated() =>
      $pb.PbList<SearchResponse>();
  @$core.pragma('dart2js:noInline')
  static SearchResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchResponse>(create);
  static SearchResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get results => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalCount() => $_clearField(3);
}

/// Get media details request
class MediaDetailsRequest extends $pb.GeneratedMessage {
  factory MediaDetailsRequest({
    $core.String? mediaId,
    $core.String? mediaType,
  }) {
    final result = create();
    if (mediaId != null) result.mediaId = mediaId;
    if (mediaType != null) result.mediaType = mediaType;
    return result;
  }

  MediaDetailsRequest._();

  factory MediaDetailsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaDetailsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaDetailsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaId')
    ..aOS(2, _omitFieldNames ? '' : 'mediaType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDetailsRequest clone() => MediaDetailsRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDetailsRequest copyWith(void Function(MediaDetailsRequest) updates) =>
      super.copyWith((message) => updates(message as MediaDetailsRequest))
          as MediaDetailsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaDetailsRequest create() => MediaDetailsRequest._();
  @$core.override
  MediaDetailsRequest createEmptyInstance() => create();
  static $pb.PbList<MediaDetailsRequest> createRepeated() =>
      $pb.PbList<MediaDetailsRequest>();
  @$core.pragma('dart2js:noInline')
  static MediaDetailsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaDetailsRequest>(create);
  static MediaDetailsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaId => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mediaType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mediaType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMediaType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMediaType() => $_clearField(2);
}

class MediaDetailsResponse extends $pb.GeneratedMessage {
  factory MediaDetailsResponse({
    MediaItem? media,
    $core.String? error,
  }) {
    final result = create();
    if (media != null) result.media = media;
    if (error != null) result.error = error;
    return result;
  }

  MediaDetailsResponse._();

  factory MediaDetailsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaDetailsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaDetailsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOM<MediaItem>(1, _omitFieldNames ? '' : 'media',
        subBuilder: MediaItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDetailsResponse clone() =>
      MediaDetailsResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaDetailsResponse copyWith(void Function(MediaDetailsResponse) updates) =>
      super.copyWith((message) => updates(message as MediaDetailsResponse))
          as MediaDetailsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaDetailsResponse create() => MediaDetailsResponse._();
  @$core.override
  MediaDetailsResponse createEmptyInstance() => create();
  static $pb.PbList<MediaDetailsResponse> createRepeated() =>
      $pb.PbList<MediaDetailsResponse>();
  @$core.pragma('dart2js:noInline')
  static MediaDetailsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MediaDetailsResponse>(create);
  static MediaDetailsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  MediaItem get media => $_getN(0);
  @$pb.TagNumber(1)
  set media(MediaItem value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMedia() => $_has(0);
  @$pb.TagNumber(1)
  void clearMedia() => $_clearField(1);
  @$pb.TagNumber(1)
  MediaItem ensureMedia() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Random media request
class RandomMediaRequest extends $pb.GeneratedMessage {
  factory RandomMediaRequest({
    $core.String? mediaType,
    $core.Iterable<$core.String>? excludeMediaIds,
    $core.int? limit,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (excludeMediaIds != null) result.excludeMediaIds.addAll(excludeMediaIds);
    if (limit != null) result.limit = limit;
    return result;
  }

  RandomMediaRequest._();

  factory RandomMediaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RandomMediaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RandomMediaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..pPS(2, _omitFieldNames ? '' : 'excludeMediaIds')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RandomMediaRequest clone() => RandomMediaRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RandomMediaRequest copyWith(void Function(RandomMediaRequest) updates) =>
      super.copyWith((message) => updates(message as RandomMediaRequest))
          as RandomMediaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RandomMediaRequest create() => RandomMediaRequest._();
  @$core.override
  RandomMediaRequest createEmptyInstance() => create();
  static $pb.PbList<RandomMediaRequest> createRepeated() =>
      $pb.PbList<RandomMediaRequest>();
  @$core.pragma('dart2js:noInline')
  static RandomMediaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RandomMediaRequest>(create);
  static RandomMediaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get excludeMediaIds => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class RandomMediaResponse extends $pb.GeneratedMessage {
  factory RandomMediaResponse({
    $core.Iterable<MediaItem>? items,
    $core.String? error,
  }) {
    final result = create();
    if (items != null) result.items.addAll(items);
    if (error != null) result.error = error;
    return result;
  }

  RandomMediaResponse._();

  factory RandomMediaResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RandomMediaResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RandomMediaResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pc<MediaItem>(1, _omitFieldNames ? '' : 'items', $pb.PbFieldType.PM,
        subBuilder: MediaItem.create)
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RandomMediaResponse clone() => RandomMediaResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RandomMediaResponse copyWith(void Function(RandomMediaResponse) updates) =>
      super.copyWith((message) => updates(message as RandomMediaResponse))
          as RandomMediaResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RandomMediaResponse create() => RandomMediaResponse._();
  @$core.override
  RandomMediaResponse createEmptyInstance() => create();
  static $pb.PbList<RandomMediaResponse> createRepeated() =>
      $pb.PbList<RandomMediaResponse>();
  @$core.pragma('dart2js:noInline')
  static RandomMediaResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RandomMediaResponse>(create);
  static RandomMediaResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<MediaItem> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Health check messages
class HealthCheckRequest extends $pb.GeneratedMessage {
  factory HealthCheckRequest() => create();

  HealthCheckRequest._();

  factory HealthCheckRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HealthCheckRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckRequest clone() => HealthCheckRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckRequest copyWith(void Function(HealthCheckRequest) updates) =>
      super.copyWith((message) => updates(message as HealthCheckRequest))
          as HealthCheckRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckRequest create() => HealthCheckRequest._();
  @$core.override
  HealthCheckRequest createEmptyInstance() => create();
  static $pb.PbList<HealthCheckRequest> createRepeated() =>
      $pb.PbList<HealthCheckRequest>();
  @$core.pragma('dart2js:noInline')
  static HealthCheckRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckRequest>(create);
  static HealthCheckRequest? _defaultInstance;
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.bool? healthy,
    $core.String? version,
    $core.Iterable<$core.MapEntry<$core.String, $core.bool>>? databaseStatus,
  }) {
    final result = create();
    if (healthy != null) result.healthy = healthy;
    if (version != null) result.version = version;
    if (databaseStatus != null)
      result.databaseStatus.addEntries(databaseStatus);
    return result;
  }

  HealthCheckResponse._();

  factory HealthCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HealthCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'healthy')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..m<$core.String, $core.bool>(3, _omitFieldNames ? '' : 'databaseStatus',
        entryClassName: 'HealthCheckResponse.DatabaseStatusEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OB,
        packageName: const $pb.PackageName('recommendation'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse clone() => HealthCheckResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse copyWith(void Function(HealthCheckResponse) updates) =>
      super.copyWith((message) => updates(message as HealthCheckResponse))
          as HealthCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse create() => HealthCheckResponse._();
  @$core.override
  HealthCheckResponse createEmptyInstance() => create();
  static $pb.PbList<HealthCheckResponse> createRepeated() =>
      $pb.PbList<HealthCheckResponse>();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(create);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get healthy => $_getBF(0);
  @$pb.TagNumber(1)
  set healthy($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHealthy() => $_has(0);
  @$pb.TagNumber(1)
  void clearHealthy() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.bool> get databaseStatus => $_getMap(2);
}

/// Get available themes request
class AvailableThemesRequest extends $pb.GeneratedMessage {
  factory AvailableThemesRequest({
    $core.String? mediaType,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    return result;
  }

  AvailableThemesRequest._();

  factory AvailableThemesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AvailableThemesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AvailableThemesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableThemesRequest clone() =>
      AvailableThemesRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableThemesRequest copyWith(
          void Function(AvailableThemesRequest) updates) =>
      super.copyWith((message) => updates(message as AvailableThemesRequest))
          as AvailableThemesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AvailableThemesRequest create() => AvailableThemesRequest._();
  @$core.override
  AvailableThemesRequest createEmptyInstance() => create();
  static $pb.PbList<AvailableThemesRequest> createRepeated() =>
      $pb.PbList<AvailableThemesRequest>();
  @$core.pragma('dart2js:noInline')
  static AvailableThemesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AvailableThemesRequest>(create);
  static AvailableThemesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);
}

class AvailableThemesResponse extends $pb.GeneratedMessage {
  factory AvailableThemesResponse({
    $core.Iterable<$core.String>? themes,
    $core.String? error,
  }) {
    final result = create();
    if (themes != null) result.themes.addAll(themes);
    if (error != null) result.error = error;
    return result;
  }

  AvailableThemesResponse._();

  factory AvailableThemesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AvailableThemesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AvailableThemesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'themes')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableThemesResponse clone() =>
      AvailableThemesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableThemesResponse copyWith(
          void Function(AvailableThemesResponse) updates) =>
      super.copyWith((message) => updates(message as AvailableThemesResponse))
          as AvailableThemesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AvailableThemesResponse create() => AvailableThemesResponse._();
  @$core.override
  AvailableThemesResponse createEmptyInstance() => create();
  static $pb.PbList<AvailableThemesResponse> createRepeated() =>
      $pb.PbList<AvailableThemesResponse>();
  @$core.pragma('dart2js:noInline')
  static AvailableThemesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AvailableThemesResponse>(create);
  static AvailableThemesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get themes => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Get available genres request
class AvailableGenresRequest extends $pb.GeneratedMessage {
  factory AvailableGenresRequest({
    $core.String? mediaType,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    return result;
  }

  AvailableGenresRequest._();

  factory AvailableGenresRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AvailableGenresRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AvailableGenresRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableGenresRequest clone() =>
      AvailableGenresRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableGenresRequest copyWith(
          void Function(AvailableGenresRequest) updates) =>
      super.copyWith((message) => updates(message as AvailableGenresRequest))
          as AvailableGenresRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AvailableGenresRequest create() => AvailableGenresRequest._();
  @$core.override
  AvailableGenresRequest createEmptyInstance() => create();
  static $pb.PbList<AvailableGenresRequest> createRepeated() =>
      $pb.PbList<AvailableGenresRequest>();
  @$core.pragma('dart2js:noInline')
  static AvailableGenresRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AvailableGenresRequest>(create);
  static AvailableGenresRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);
}

class AvailableGenresResponse extends $pb.GeneratedMessage {
  factory AvailableGenresResponse({
    $core.Iterable<$core.String>? genres,
    $core.String? error,
  }) {
    final result = create();
    if (genres != null) result.genres.addAll(genres);
    if (error != null) result.error = error;
    return result;
  }

  AvailableGenresResponse._();

  factory AvailableGenresResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AvailableGenresResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AvailableGenresResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'genres')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableGenresResponse clone() =>
      AvailableGenresResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AvailableGenresResponse copyWith(
          void Function(AvailableGenresResponse) updates) =>
      super.copyWith((message) => updates(message as AvailableGenresResponse))
          as AvailableGenresResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AvailableGenresResponse create() => AvailableGenresResponse._();
  @$core.override
  AvailableGenresResponse createEmptyInstance() => create();
  static $pb.PbList<AvailableGenresResponse> createRepeated() =>
      $pb.PbList<AvailableGenresResponse>();
  @$core.pragma('dart2js:noInline')
  static AvailableGenresResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AvailableGenresResponse>(create);
  static AvailableGenresResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get genres => $_getList(0);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

/// Search themes request
class SearchThemesRequest extends $pb.GeneratedMessage {
  factory SearchThemesRequest({
    $core.String? mediaType,
    $core.String? query,
    $core.int? limit,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (query != null) result.query = query;
    if (limit != null) result.limit = limit;
    return result;
  }

  SearchThemesRequest._();

  factory SearchThemesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchThemesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchThemesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchThemesRequest clone() => SearchThemesRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchThemesRequest copyWith(void Function(SearchThemesRequest) updates) =>
      super.copyWith((message) => updates(message as SearchThemesRequest))
          as SearchThemesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchThemesRequest create() => SearchThemesRequest._();
  @$core.override
  SearchThemesRequest createEmptyInstance() => create();
  static $pb.PbList<SearchThemesRequest> createRepeated() =>
      $pb.PbList<SearchThemesRequest>();
  @$core.pragma('dart2js:noInline')
  static SearchThemesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchThemesRequest>(create);
  static SearchThemesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class SearchThemesResponse extends $pb.GeneratedMessage {
  factory SearchThemesResponse({
    $core.Iterable<$core.String>? themes,
    $core.int? totalCount,
    $core.String? error,
  }) {
    final result = create();
    if (themes != null) result.themes.addAll(themes);
    if (totalCount != null) result.totalCount = totalCount;
    if (error != null) result.error = error;
    return result;
  }

  SearchThemesResponse._();

  factory SearchThemesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchThemesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchThemesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'themes')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'totalCount', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchThemesResponse clone() =>
      SearchThemesResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchThemesResponse copyWith(void Function(SearchThemesResponse) updates) =>
      super.copyWith((message) => updates(message as SearchThemesResponse))
          as SearchThemesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchThemesResponse create() => SearchThemesResponse._();
  @$core.override
  SearchThemesResponse createEmptyInstance() => create();
  static $pb.PbList<SearchThemesResponse> createRepeated() =>
      $pb.PbList<SearchThemesResponse>();
  @$core.pragma('dart2js:noInline')
  static SearchThemesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchThemesResponse>(create);
  static SearchThemesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get themes => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get totalCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

/// Search genres request
class SearchGenresRequest extends $pb.GeneratedMessage {
  factory SearchGenresRequest({
    $core.String? mediaType,
    $core.String? query,
    $core.int? limit,
  }) {
    final result = create();
    if (mediaType != null) result.mediaType = mediaType;
    if (query != null) result.query = query;
    if (limit != null) result.limit = limit;
    return result;
  }

  SearchGenresRequest._();

  factory SearchGenresRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchGenresRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchGenresRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaType')
    ..aOS(2, _omitFieldNames ? '' : 'query')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'limit', $pb.PbFieldType.O3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchGenresRequest clone() => SearchGenresRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchGenresRequest copyWith(void Function(SearchGenresRequest) updates) =>
      super.copyWith((message) => updates(message as SearchGenresRequest))
          as SearchGenresRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchGenresRequest create() => SearchGenresRequest._();
  @$core.override
  SearchGenresRequest createEmptyInstance() => create();
  static $pb.PbList<SearchGenresRequest> createRepeated() =>
      $pb.PbList<SearchGenresRequest>();
  @$core.pragma('dart2js:noInline')
  static SearchGenresRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchGenresRequest>(create);
  static SearchGenresRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get query => $_getSZ(1);
  @$pb.TagNumber(2)
  set query($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class SearchGenresResponse extends $pb.GeneratedMessage {
  factory SearchGenresResponse({
    $core.Iterable<$core.String>? genres,
    $core.int? totalCount,
    $core.String? error,
  }) {
    final result = create();
    if (genres != null) result.genres.addAll(genres);
    if (totalCount != null) result.totalCount = totalCount;
    if (error != null) result.error = error;
    return result;
  }

  SearchGenresResponse._();

  factory SearchGenresResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchGenresResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchGenresResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..pPS(1, _omitFieldNames ? '' : 'genres')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'totalCount', $pb.PbFieldType.O3)
    ..aOS(3, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchGenresResponse clone() =>
      SearchGenresResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchGenresResponse copyWith(void Function(SearchGenresResponse) updates) =>
      super.copyWith((message) => updates(message as SearchGenresResponse))
          as SearchGenresResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchGenresResponse create() => SearchGenresResponse._();
  @$core.override
  SearchGenresResponse createEmptyInstance() => create();
  static $pb.PbList<SearchGenresResponse> createRepeated() =>
      $pb.PbList<SearchGenresResponse>();
  @$core.pragma('dart2js:noInline')
  static SearchGenresResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchGenresResponse>(create);
  static SearchGenresResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get genres => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get totalCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get error => $_getSZ(2);
  @$pb.TagNumber(3)
  set error($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasError() => $_has(2);
  @$pb.TagNumber(3)
  void clearError() => $_clearField(3);
}

/// Core media item representation
class MediaItem extends $pb.GeneratedMessage {
  factory MediaItem({
    $core.String? mediaId,
    $core.String? title,
    $core.String? primaryCreator,
    $core.String? mediaType,
    $core.String? album,
    $core.String? coverArtUrl,
    $core.String? description,
    $core.String? wikiUrl,
    $core.String? wikidataId,
    $core.String? themes,
    $core.double? similarityScore,
    $core.String? reasoning,
    $core.String? youtubeId,
    $core.String? spotifyId,
    $core.String? genres,
  }) {
    final result = create();
    if (mediaId != null) result.mediaId = mediaId;
    if (title != null) result.title = title;
    if (primaryCreator != null) result.primaryCreator = primaryCreator;
    if (mediaType != null) result.mediaType = mediaType;
    if (album != null) result.album = album;
    if (coverArtUrl != null) result.coverArtUrl = coverArtUrl;
    if (description != null) result.description = description;
    if (wikiUrl != null) result.wikiUrl = wikiUrl;
    if (wikidataId != null) result.wikidataId = wikidataId;
    if (themes != null) result.themes = themes;
    if (similarityScore != null) result.similarityScore = similarityScore;
    if (reasoning != null) result.reasoning = reasoning;
    if (youtubeId != null) result.youtubeId = youtubeId;
    if (spotifyId != null) result.spotifyId = spotifyId;
    if (genres != null) result.genres = genres;
    return result;
  }

  MediaItem._();

  factory MediaItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MediaItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MediaItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'recommendation'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'mediaId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'primaryCreator')
    ..aOS(4, _omitFieldNames ? '' : 'mediaType')
    ..aOS(5, _omitFieldNames ? '' : 'album')
    ..aOS(6, _omitFieldNames ? '' : 'coverArtUrl')
    ..aOS(7, _omitFieldNames ? '' : 'description')
    ..aOS(8, _omitFieldNames ? '' : 'wikiUrl')
    ..aOS(9, _omitFieldNames ? '' : 'wikidataId')
    ..aOS(10, _omitFieldNames ? '' : 'themes')
    ..a<$core.double>(
        11, _omitFieldNames ? '' : 'similarityScore', $pb.PbFieldType.OD)
    ..aOS(12, _omitFieldNames ? '' : 'reasoning')
    ..aOS(13, _omitFieldNames ? '' : 'youtubeId')
    ..aOS(14, _omitFieldNames ? '' : 'spotifyId')
    ..aOS(15, _omitFieldNames ? '' : 'genres')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem clone() => MediaItem()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MediaItem copyWith(void Function(MediaItem) updates) =>
      super.copyWith((message) => updates(message as MediaItem)) as MediaItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MediaItem create() => MediaItem._();
  @$core.override
  MediaItem createEmptyInstance() => create();
  static $pb.PbList<MediaItem> createRepeated() => $pb.PbList<MediaItem>();
  @$core.pragma('dart2js:noInline')
  static MediaItem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MediaItem>(create);
  static MediaItem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mediaId => $_getSZ(0);
  @$pb.TagNumber(1)
  set mediaId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMediaId() => $_has(0);
  @$pb.TagNumber(1)
  void clearMediaId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get primaryCreator => $_getSZ(2);
  @$pb.TagNumber(3)
  set primaryCreator($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrimaryCreator() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrimaryCreator() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get mediaType => $_getSZ(3);
  @$pb.TagNumber(4)
  set mediaType($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMediaType() => $_has(3);
  @$pb.TagNumber(4)
  void clearMediaType() => $_clearField(4);

  /// Optional fields based on media type
  @$pb.TagNumber(5)
  $core.String get album => $_getSZ(4);
  @$pb.TagNumber(5)
  set album($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAlbum() => $_has(4);
  @$pb.TagNumber(5)
  void clearAlbum() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get coverArtUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set coverArtUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCoverArtUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoverArtUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get description => $_getSZ(6);
  @$pb.TagNumber(7)
  set description($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDescription() => $_has(6);
  @$pb.TagNumber(7)
  void clearDescription() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get wikiUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set wikiUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWikiUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearWikiUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get wikidataId => $_getSZ(8);
  @$pb.TagNumber(9)
  set wikidataId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWikidataId() => $_has(8);
  @$pb.TagNumber(9)
  void clearWikidataId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get themes => $_getSZ(9);
  @$pb.TagNumber(10)
  set themes($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasThemes() => $_has(9);
  @$pb.TagNumber(10)
  void clearThemes() => $_clearField(10);

  /// Recommendation context (when returned as recommendation)
  @$pb.TagNumber(11)
  $core.double get similarityScore => $_getN(10);
  @$pb.TagNumber(11)
  set similarityScore($core.double value) => $_setDouble(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSimilarityScore() => $_has(10);
  @$pb.TagNumber(11)
  void clearSimilarityScore() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get reasoning => $_getSZ(11);
  @$pb.TagNumber(12)
  set reasoning($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReasoning() => $_has(11);
  @$pb.TagNumber(12)
  void clearReasoning() => $_clearField(12);

  /// External service IDs
  @$pb.TagNumber(13)
  $core.String get youtubeId => $_getSZ(12);
  @$pb.TagNumber(13)
  set youtubeId($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasYoutubeId() => $_has(12);
  @$pb.TagNumber(13)
  void clearYoutubeId() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get spotifyId => $_getSZ(13);
  @$pb.TagNumber(14)
  set spotifyId($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSpotifyId() => $_has(13);
  @$pb.TagNumber(14)
  void clearSpotifyId() => $_clearField(14);

  /// Additional metadata
  @$pb.TagNumber(15)
  $core.String get genres => $_getSZ(14);
  @$pb.TagNumber(15)
  set genres($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasGenres() => $_has(14);
  @$pb.TagNumber(15)
  void clearGenres() => $_clearField(15);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
