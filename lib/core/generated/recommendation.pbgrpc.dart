// This is a generated file - do not edit.
//
// Generated from recommendation.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'recommendation.pb.dart' as $0;

export 'recommendation.pb.dart';

/// RecommendationService handles vector-based media recommendations
@$pb.GrpcServiceName('recommendation.RecommendationService')
class RecommendationServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  RecommendationServiceClient(super.channel,
      {super.options, super.interceptors});

  /// Generate recommendations based on user preferences and constraints
  $grpc.ResponseFuture<$0.RecommendationResponse> getRecommendations(
    $0.RecommendationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getRecommendations, request, options: options);
  }

  /// Get similar items to a specific media item
  $grpc.ResponseFuture<$0.SimilarItemsResponse> getSimilarItems(
    $0.SimilarItemsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSimilarItems, request, options: options);
  }

  /// Search for media items with constraints
  $grpc.ResponseFuture<$0.SearchResponse> searchMedia(
    $0.SearchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchMedia, request, options: options);
  }

  /// Get media item details by vector media ID
  $grpc.ResponseFuture<$0.MediaDetailsResponse> getMediaDetails(
    $0.MediaDetailsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMediaDetails, request, options: options);
  }

  /// Get random media items for exploration
  $grpc.ResponseFuture<$0.RandomMediaResponse> getRandomMedia(
    $0.RandomMediaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getRandomMedia, request, options: options);
  }

  /// Health check
  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $0.HealthCheckRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  /// Get available themes for a media type
  $grpc.ResponseFuture<$0.AvailableThemesResponse> getAvailableThemes(
    $0.AvailableThemesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAvailableThemes, request, options: options);
  }

  /// Get available genres for a media type
  $grpc.ResponseFuture<$0.AvailableGenresResponse> getAvailableGenres(
    $0.AvailableGenresRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAvailableGenres, request, options: options);
  }

  /// Search themes by query
  $grpc.ResponseFuture<$0.SearchThemesResponse> searchThemes(
    $0.SearchThemesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchThemes, request, options: options);
  }

  /// Search genres by query
  $grpc.ResponseFuture<$0.SearchGenresResponse> searchGenres(
    $0.SearchGenresRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchGenres, request, options: options);
  }

  // method descriptors

  static final _$getRecommendations =
      $grpc.ClientMethod<$0.RecommendationRequest, $0.RecommendationResponse>(
          '/recommendation.RecommendationService/GetRecommendations',
          ($0.RecommendationRequest value) => value.writeToBuffer(),
          $0.RecommendationResponse.fromBuffer);
  static final _$getSimilarItems =
      $grpc.ClientMethod<$0.SimilarItemsRequest, $0.SimilarItemsResponse>(
          '/recommendation.RecommendationService/GetSimilarItems',
          ($0.SimilarItemsRequest value) => value.writeToBuffer(),
          $0.SimilarItemsResponse.fromBuffer);
  static final _$searchMedia =
      $grpc.ClientMethod<$0.SearchRequest, $0.SearchResponse>(
          '/recommendation.RecommendationService/SearchMedia',
          ($0.SearchRequest value) => value.writeToBuffer(),
          $0.SearchResponse.fromBuffer);
  static final _$getMediaDetails =
      $grpc.ClientMethod<$0.MediaDetailsRequest, $0.MediaDetailsResponse>(
          '/recommendation.RecommendationService/GetMediaDetails',
          ($0.MediaDetailsRequest value) => value.writeToBuffer(),
          $0.MediaDetailsResponse.fromBuffer);
  static final _$getRandomMedia =
      $grpc.ClientMethod<$0.RandomMediaRequest, $0.RandomMediaResponse>(
          '/recommendation.RecommendationService/GetRandomMedia',
          ($0.RandomMediaRequest value) => value.writeToBuffer(),
          $0.RandomMediaResponse.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$0.HealthCheckRequest, $0.HealthCheckResponse>(
          '/recommendation.RecommendationService/HealthCheck',
          ($0.HealthCheckRequest value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
  static final _$getAvailableThemes =
      $grpc.ClientMethod<$0.AvailableThemesRequest, $0.AvailableThemesResponse>(
          '/recommendation.RecommendationService/GetAvailableThemes',
          ($0.AvailableThemesRequest value) => value.writeToBuffer(),
          $0.AvailableThemesResponse.fromBuffer);
  static final _$getAvailableGenres =
      $grpc.ClientMethod<$0.AvailableGenresRequest, $0.AvailableGenresResponse>(
          '/recommendation.RecommendationService/GetAvailableGenres',
          ($0.AvailableGenresRequest value) => value.writeToBuffer(),
          $0.AvailableGenresResponse.fromBuffer);
  static final _$searchThemes =
      $grpc.ClientMethod<$0.SearchThemesRequest, $0.SearchThemesResponse>(
          '/recommendation.RecommendationService/SearchThemes',
          ($0.SearchThemesRequest value) => value.writeToBuffer(),
          $0.SearchThemesResponse.fromBuffer);
  static final _$searchGenres =
      $grpc.ClientMethod<$0.SearchGenresRequest, $0.SearchGenresResponse>(
          '/recommendation.RecommendationService/SearchGenres',
          ($0.SearchGenresRequest value) => value.writeToBuffer(),
          $0.SearchGenresResponse.fromBuffer);
}

@$pb.GrpcServiceName('recommendation.RecommendationService')
abstract class RecommendationServiceBase extends $grpc.Service {
  $core.String get $name => 'recommendation.RecommendationService';

  RecommendationServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RecommendationRequest,
            $0.RecommendationResponse>(
        'GetRecommendations',
        getRecommendations_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecommendationRequest.fromBuffer(value),
        ($0.RecommendationResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SimilarItemsRequest, $0.SimilarItemsResponse>(
            'GetSimilarItems',
            getSimilarItems_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SimilarItemsRequest.fromBuffer(value),
            ($0.SimilarItemsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SearchRequest, $0.SearchResponse>(
        'SearchMedia',
        searchMedia_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SearchRequest.fromBuffer(value),
        ($0.SearchResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.MediaDetailsRequest, $0.MediaDetailsResponse>(
            'GetMediaDetails',
            getMediaDetails_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.MediaDetailsRequest.fromBuffer(value),
            ($0.MediaDetailsResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RandomMediaRequest, $0.RandomMediaResponse>(
            'GetRandomMedia',
            getRandomMedia_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RandomMediaRequest.fromBuffer(value),
            ($0.RandomMediaResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.HealthCheckRequest, $0.HealthCheckResponse>(
            'HealthCheck',
            healthCheck_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.HealthCheckRequest.fromBuffer(value),
            ($0.HealthCheckResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AvailableThemesRequest,
            $0.AvailableThemesResponse>(
        'GetAvailableThemes',
        getAvailableThemes_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AvailableThemesRequest.fromBuffer(value),
        ($0.AvailableThemesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AvailableGenresRequest,
            $0.AvailableGenresResponse>(
        'GetAvailableGenres',
        getAvailableGenres_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AvailableGenresRequest.fromBuffer(value),
        ($0.AvailableGenresResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchThemesRequest, $0.SearchThemesResponse>(
            'SearchThemes',
            searchThemes_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchThemesRequest.fromBuffer(value),
            ($0.SearchThemesResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchGenresRequest, $0.SearchGenresResponse>(
            'SearchGenres',
            searchGenres_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchGenresRequest.fromBuffer(value),
            ($0.SearchGenresResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RecommendationResponse> getRecommendations_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecommendationRequest> $request) async {
    return getRecommendations($call, await $request);
  }

  $async.Future<$0.RecommendationResponse> getRecommendations(
      $grpc.ServiceCall call, $0.RecommendationRequest request);

  $async.Future<$0.SimilarItemsResponse> getSimilarItems_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SimilarItemsRequest> $request) async {
    return getSimilarItems($call, await $request);
  }

  $async.Future<$0.SimilarItemsResponse> getSimilarItems(
      $grpc.ServiceCall call, $0.SimilarItemsRequest request);

  $async.Future<$0.SearchResponse> searchMedia_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.SearchRequest> $request) async {
    return searchMedia($call, await $request);
  }

  $async.Future<$0.SearchResponse> searchMedia(
      $grpc.ServiceCall call, $0.SearchRequest request);

  $async.Future<$0.MediaDetailsResponse> getMediaDetails_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.MediaDetailsRequest> $request) async {
    return getMediaDetails($call, await $request);
  }

  $async.Future<$0.MediaDetailsResponse> getMediaDetails(
      $grpc.ServiceCall call, $0.MediaDetailsRequest request);

  $async.Future<$0.RandomMediaResponse> getRandomMedia_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RandomMediaRequest> $request) async {
    return getRandomMedia($call, await $request);
  }

  $async.Future<$0.RandomMediaResponse> getRandomMedia(
      $grpc.ServiceCall call, $0.RandomMediaRequest request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre($grpc.ServiceCall $call,
      $async.Future<$0.HealthCheckRequest> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $0.HealthCheckRequest request);

  $async.Future<$0.AvailableThemesResponse> getAvailableThemes_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AvailableThemesRequest> $request) async {
    return getAvailableThemes($call, await $request);
  }

  $async.Future<$0.AvailableThemesResponse> getAvailableThemes(
      $grpc.ServiceCall call, $0.AvailableThemesRequest request);

  $async.Future<$0.AvailableGenresResponse> getAvailableGenres_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AvailableGenresRequest> $request) async {
    return getAvailableGenres($call, await $request);
  }

  $async.Future<$0.AvailableGenresResponse> getAvailableGenres(
      $grpc.ServiceCall call, $0.AvailableGenresRequest request);

  $async.Future<$0.SearchThemesResponse> searchThemes_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchThemesRequest> $request) async {
    return searchThemes($call, await $request);
  }

  $async.Future<$0.SearchThemesResponse> searchThemes(
      $grpc.ServiceCall call, $0.SearchThemesRequest request);

  $async.Future<$0.SearchGenresResponse> searchGenres_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchGenresRequest> $request) async {
    return searchGenres($call, await $request);
  }

  $async.Future<$0.SearchGenresResponse> searchGenres(
      $grpc.ServiceCall call, $0.SearchGenresRequest request);
}
