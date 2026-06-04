import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_checker.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/models/referral_details_model.dart';
import 'package:ride_sharing_user_app/features/refer_and_earn/domain/services/refer_earn_service_interface.dart';
import 'package:ride_sharing_user_app/features/wallet/domain/models/transaction_model.dart';

class ReferAndEarnController extends GetxController implements GetxService {
  final ReferEarnServiceInterface referEarnServiceInterface;

  ReferAndEarnController({required this.referEarnServiceInterface});

  List<String> referAndEarnType = ['referral_details', 'earning'];
  int currentTabIndex = 0;
  bool isLoading = false;
  bool isPointsClubReferralLoading = false;
  ScrollController scrollController = ScrollController();

  TransactionModel? referralModel;
  ReferralDetailsModel? referralDetails;

  List<PointsClubReferralItem> pointsClubReferrals = [];
  int pointsClubReferralOffset = 0;
  int pointsClubReferralTotalSize = 0;

  String get referralCode => (referralDetails?.data?.referralCode ?? '').trim();

  String get referralLink {
    return referralCode;
  }

  String get referralShareText {
    if (referralCode.isEmpty) {
      return 'Estou te convidando para usar o app Lokally e participar do Clube de Pontos.';
    }

    return 'Estou te convidando para usar o app Lokally e participar do Clube de Pontos.\n\n'
        'Ao se cadastrar, informe meu código de indicação:\n\n'
        '$referralCode';
  }

  void updateCurrentTabIndex(int index, {bool isUpdate = false}) {
    currentTabIndex = index;

    if (index == 1 &&
        pointsClubReferrals.isEmpty &&
        !isPointsClubReferralLoading) {
      getPointsClubReferrals(0);
    }

    if (isUpdate) {
      update();
    }
  }

  Future<Response> getEarningHistoryList(int offset) async {
    isLoading = true;
    update();

    Response response =
        await referEarnServiceInterface.getEarningHistoryList(offset);

    if (response.statusCode == 200) {
      isLoading = false;

      if (offset == 1) {
        referralModel = TransactionModel.fromJson(response.body);
      } else {
        referralModel!.data!.addAll(
          TransactionModel.fromJson(response.body).data!,
        );
        referralModel!.offset = TransactionModel.fromJson(response.body).offset;
        referralModel!.totalSize =
            TransactionModel.fromJson(response.body).totalSize;
      }
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
    return response;
  }

  Future<Response> getPointsClubReferrals(int offset) async {
    isPointsClubReferralLoading = true;
    update();

    Response response =
        await referEarnServiceInterface.getPointsClubReferrals(offset);

    if (response.statusCode == 200) {
      final Map<String, dynamic> body =
          Map<String, dynamic>.from(response.body ?? {});
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(body['data'] ?? {});
      final List<dynamic> items = data['items'] is List ? data['items'] : [];

      final List<PointsClubReferralItem> parsedItems = items
          .whereType<Map>()
          .map((item) => PointsClubReferralItem.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      if (offset == 0) {
        pointsClubReferrals = parsedItems;
      } else {
        pointsClubReferrals.addAll(parsedItems);
      }

      pointsClubReferralOffset =
          int.tryParse((data['offset'] ?? offset).toString()) ?? offset;
      pointsClubReferralTotalSize =
          int.tryParse((data['total_size'] ?? parsedItems.length).toString()) ??
              parsedItems.length;

      isPointsClubReferralLoading = false;
    } else {
      isPointsClubReferralLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
    return response;
  }

  Future<void> getReferralDetails() async {
    isLoading = true;
    update();

    Response response = await referEarnServiceInterface.getReferralDetails();

    if (response.statusCode == 200) {
      referralDetails = ReferralDetailsModel.fromJson(response.body);
      isLoading = false;
    } else {
      isLoading = false;
      ApiChecker.checkApi(response);
    }

    update();
  }
}

class PointsClubReferralItem {
  final String id;
  final String referredUserId;
  final String referredName;
  final String locationLabel;
  final bool isActive;
  final String status;
  final String statusLabel;
  final String nextStepLabel;
  final int completedSteps;
  final int targetSteps;
  final String progressLabel;
  final double progressPercent;
  final int referrerPointsReleased;
  final int referredPointsReleased;
  final int referrerPointsRemaining;
  final int maxReferrerPoints;
  final int maxReferredPoints;
  final String? createdAt;
  final String? createdAtLabel;
  final String? completedAt;
  final String? completedAtLabel;

  PointsClubReferralItem({
    required this.id,
    required this.referredUserId,
    required this.referredName,
    required this.locationLabel,
    required this.isActive,
    required this.status,
    required this.statusLabel,
    required this.nextStepLabel,
    required this.completedSteps,
    required this.targetSteps,
    required this.progressLabel,
    required this.progressPercent,
    required this.referrerPointsReleased,
    required this.referredPointsReleased,
    required this.referrerPointsRemaining,
    required this.maxReferrerPoints,
    required this.maxReferredPoints,
    this.createdAt,
    this.createdAtLabel,
    this.completedAt,
    this.completedAtLabel,
  });

  factory PointsClubReferralItem.fromJson(Map<String, dynamic> json) {
    return PointsClubReferralItem(
      id: _readString(json['id']),
      referredUserId: _readString(json['referred_user_id']),
      referredName:
          _readString(json['referred_name'], fallback: 'Usuário indicado'),
      locationLabel:
          _readString(json['location_label'], fallback: 'Cidade não informada'),
      isActive: _readBool(json['is_active']),
      status: _readString(json['status']),
      statusLabel: _readString(json['status_label']),
      nextStepLabel: _readString(json['next_step_label']),
      completedSteps: _readInt(json['completed_steps']),
      targetSteps: _readInt(json['target_steps'], fallback: 5),
      progressLabel: _readString(json['progress_label']),
      progressPercent: _readDouble(json['progress_percent']),
      referrerPointsReleased: _readInt(json['referrer_points_released']),
      referredPointsReleased: _readInt(json['referred_points_released']),
      referrerPointsRemaining: _readInt(json['referrer_points_remaining']),
      maxReferrerPoints: _readInt(json['max_referrer_points'], fallback: 200),
      maxReferredPoints: _readInt(json['max_referred_points'], fallback: 50),
      createdAt: _readNullableString(json['created_at']),
      createdAtLabel: _readNullableString(json['created_at_label']),
      completedAt: _readNullableString(json['completed_at']),
      completedAtLabel: _readNullableString(json['completed_at_label']),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final String parsed = (value ?? '').toString().trim();
    return parsed.isEmpty ? fallback : parsed;
  }

  static String? _readNullableString(dynamic value) {
    final String parsed = (value ?? '').toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    return int.tryParse((value ?? fallback).toString()) ?? fallback;
  }

  static double _readDouble(dynamic value, {double fallback = 0}) {
    return double.tryParse((value ?? fallback).toString()) ?? fallback;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value == 1;
    }

    final String parsed = (value ?? '').toString().toLowerCase().trim();

    return parsed == '1' || parsed == 'true' || parsed == 'yes';
  }
}
