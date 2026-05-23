import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';

class PointsClubHomeScreen extends StatefulWidget {
  const PointsClubHomeScreen({super.key});

  @override
  State<PointsClubHomeScreen> createState() => _PointsClubHomeScreenState();
}

class _PointsClubHomeScreenState extends State<PointsClubHomeScreen> {
  final PageController _heroController = PageController(viewportFraction: 0.92);
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isRedeeming = false;
  String? _errorMessage;
  String _selectedCategory = 'all';

  int _pointsBalance = 0;
  int _earnedPoints = 0;
  int _usedPoints = 0;

  List<PointsClubReward> _rewards = <PointsClubReward>[];

  @override
  void initState() {
    super.initState();
    _loadClub();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClub() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ApiClient apiClient = Get.find<ApiClient>();

      final Response summaryResponse =
          await apiClient.getData(_PointsClubEndpoints.summary);
      final Response rewardsResponse =
          await apiClient.getData(_PointsClubEndpoints.rewards);

      if (summaryResponse.statusCode == 200 && summaryResponse.body is Map) {
        final Map<String, dynamic> summaryBody =
            Map<String, dynamic>.from(summaryResponse.body as Map);
        final Map<String, dynamic> data = _asMap(summaryBody['data']);

        _pointsBalance = _asInt(data['points_balance']);
        _earnedPoints = _asInt(data['earned_points']);
        _usedPoints = _asInt(data['used_points']);
      }

      if (rewardsResponse.statusCode == 200 && rewardsResponse.body is Map) {
        final Map<String, dynamic> rewardsBody =
            Map<String, dynamic>.from(rewardsResponse.body as Map);
        final Map<String, dynamic> data = _asMap(rewardsBody['data']);
        final List<dynamic> items = data['items'] is List
            ? List<dynamic>.from(data['items'] as List)
            : <dynamic>[];

        _rewards = items
            .whereType<Map>()
            .map((item) => PointsClubReward.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível carregar o Clube de Pontos agora.';
        });
      }
    }
  }

  Future<void> _redeemReward(PointsClubReward reward, int quantity) async {
    if (_isRedeeming) {
      return;
    }

    final int safeQuantity = reward.allowQuantity ? quantity : 1;
    final int totalPoints = reward.pointsRequired * safeQuantity;

    if (_pointsBalance < totalPoints) {
      Get.snackbar(
        'Pontos insuficientes',
        'Você precisa de ${_formatPoints(totalPoints)} pontos para esta troca.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final Response response = await Get.find<ApiClient>().postData(
        _PointsClubEndpoints.redeem(reward.id),
        <String, dynamic>{
          'quantity': safeQuantity,
        },
      );

      if (response.statusCode == 200 && response.body is Map) {
        final Map<String, dynamic> body =
            Map<String, dynamic>.from(response.body as Map);
        final Map<String, dynamic> data = _asMap(body['data']);
        final List<dynamic> rawVouchers = data['vouchers'] is List
            ? List<dynamic>.from(data['vouchers'] as List)
            : <dynamic>[];

        final List<String> voucherCodes = rawVouchers
            .whereType<Map>()
            .map((item) => '${item['voucher_code'] ?? ''}')
            .where((code) => code.trim().isNotEmpty)
            .toList();

        final List<String> luckyNumbers = rawVouchers
            .whereType<Map>()
            .map((item) => '${item['lucky_number'] ?? ''}')
            .where((number) => number.trim().isNotEmpty)
            .toList();

        if (luckyNumbers.isEmpty && data['lucky_numbers'] is List) {
          luckyNumbers.addAll(
            List<dynamic>.from(data['lucky_numbers'] as List)
                .map((item) => '$item')
                .where((number) => number.trim().isNotEmpty),
          );
        }

        final String singleVoucherCode = '${data['voucher_code'] ?? ''}';
        if (voucherCodes.isEmpty && singleVoucherCode.trim().isNotEmpty) {
          voucherCodes.add(singleVoucherCode);
        }

        final String singleLuckyNumber = '${data['lucky_number'] ?? ''}';
        if (luckyNumbers.isEmpty && singleLuckyNumber.trim().isNotEmpty) {
          luckyNumbers.add(singleLuckyNumber);
        }

        if (mounted) {
          _showRedeemSuccess(
            reward: reward,
            voucherCodes: voucherCodes,
            luckyNumbers: luckyNumbers,
            pointsBalance: _asInt(data['points_balance']),
            quantity: _asInt(data['quantity']) > 0
                ? _asInt(data['quantity'])
                : safeQuantity,
            totalPointsDebited: _asInt(data['total_points_debited']) > 0
                ? _asInt(data['total_points_debited'])
                : totalPoints,
          );

          await _loadClub();
        }
      } else {
        String message = 'Não foi possível realizar a troca.';
        if (response.body is Map) {
          final Map<String, dynamic> body =
              Map<String, dynamic>.from(response.body as Map);
          final Map<String, dynamic> data = _asMap(body['data']);
          message = '${data['message'] ?? body['message'] ?? message}';
        }

        Get.snackbar('Ops', message, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar(
        'Ops',
        'Não foi possível realizar a troca no momento.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() => _isRedeeming = false);
      }
    }
  }

  void _showRedeemSuccess({
    required PointsClubReward reward,
    required List<String> voucherCodes,
    required List<String> luckyNumbers,
    required int pointsBalance,
    required int quantity,
    required int totalPointsDebited,
  }) {
    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 76,
                  width: 76,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        _PointsClubColors.primary,
                        _PointsClubColors.lime
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Troca realizada!',
                  style: textBold.copyWith(
                    fontSize: 23,
                    color: _PointsClubColors.deepGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  reward.title,
                  style: textMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: _PointsClubColors.textSoft,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _PointsClubColors.softLime,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _PointsClubColors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _successMetric(
                          title: 'Quantidade',
                          value: quantity.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color:
                            _PointsClubColors.primary.withValues(alpha: 0.18),
                      ),
                      Expanded(
                        child: _successMetric(
                          title: 'Pontos usados',
                          value: _formatPoints(totalPointsDebited),
                        ),
                      ),
                    ],
                  ),
                ),
                if (luckyNumbers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _PointsClubColors.lime.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            _PointsClubColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          luckyNumbers.length == 1
                              ? 'Número da sorte gerado'
                              : 'Números da sorte gerados',
                          style: textRegular.copyWith(
                            color: _PointsClubColors.textSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: luckyNumbers
                              .map(
                                (number) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: SelectableText(
                                    number,
                                    style: textBold.copyWith(
                                      color: _PointsClubColors.deepGreen,
                                      fontSize: 17,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (voucherCodes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _PointsClubColors.softGreen,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            _PointsClubColors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          voucherCodes.length == 1
                              ? 'Código do voucher'
                              : 'Códigos gerados',
                          style: textRegular.copyWith(
                            color: _PointsClubColors.textSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 170),
                          child: SingleChildScrollView(
                            child: Column(
                              children: voucherCodes
                                  .map(
                                    (code) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: SelectableText(
                                        code,
                                        textAlign: TextAlign.center,
                                        style: textBold.copyWith(
                                          color: _PointsClubColors.deepGreen,
                                          fontSize: 16,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Seu saldo atualizado: ${_formatPoints(pointsBalance)} pontos',
                  style: textMedium.copyWith(
                    color: _PointsClubColors.deepGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PointsClubColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Entendi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _successMetric({
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: textBold.copyWith(
            color: _PointsClubColors.deepGreen,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: textRegular.copyWith(
            color: _PointsClubColors.textSoft,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<PointsClubReward> get _filteredRewards {
    if (_selectedCategory == 'all') {
      return _rewards;
    }

    return _rewards
        .where((reward) =>
            _categoryForReward(reward.rewardType).id == _selectedCategory)
        .toList();
  }

  List<PointsClubReward> get _featuredRewards {
    final List<PointsClubReward> withImage =
        _rewards.where((reward) => reward.imageUrl.isNotEmpty).toList();

    if (withImage.isNotEmpty) {
      return withImage.take(5).toList();
    }

    return _rewards.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _PointsClubColors.primary,
          onRefresh: _loadClub,
          child: _isLoading
              ? const _PointsClubLoading()
              : _errorMessage != null
                  ? _PointsClubError(
                      message: _errorMessage!,
                      onRetry: _loadClub,
                    )
                  : CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero(context)),
                        SliverToBoxAdapter(child: _buildCategoryGrid(context)),
                        SliverToBoxAdapter(child: _buildMainCta(context)),
                        SliverToBoxAdapter(
                            child: _buildReportShortcut(context)),
                        SliverToBoxAdapter(child: _buildFeatureBanner(context)),
                        SliverToBoxAdapter(child: _buildCouponStrip(context)),
                        SliverToBoxAdapter(child: _buildBenefits(context)),
                        SliverToBoxAdapter(
                            child: _buildRewardsSection(context)),
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 22,
        right: 22,
        bottom: 22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PointsClubColors.deepGreen,
            _PointsClubColors.primary,
            _PointsClubColors.vibrantGreen,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(64),
          bottomRight: Radius.circular(64),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -55,
            child: _circle(160, Colors.white.withValues(alpha: 0.11)),
          ),
          Positioned(
            left: -60,
            bottom: -55,
            child: _circle(150, Colors.white.withValues(alpha: 0.09)),
          ),
          Positioned(
            right: 18,
            bottom: 20,
            child: Transform.rotate(
              angle: -0.28,
              child: Icon(
                Icons.confirmation_number_rounded,
                color: _PointsClubColors.lime.withValues(alpha: 0.55),
                size: 58,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roundHeroButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: Get.back,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.diamond_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatPoints(_pointsBalance)} pts',
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _roundHeroButton(
                    icon: Icons.receipt_long_rounded,
                    onTap: _openMyVouchers,
                  ),
                  const SizedBox(width: 10),
                  _roundHeroButton(
                    icon: Icons.info_outline_rounded,
                    onTap: _showTermsInfo,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'CLUBE DE PONTOS\nLOKALLY',
                style: textBold.copyWith(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.03,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  'Use o app da Lokally, gere pontos e troque por descontos em viagens, entregas, compras no marketplace e parceiros locais, números da sorte para concorrer a prêmios incríveis!',
                  style: textMedium.copyWith(
                    color: Colors.white,
                    height: 1.35,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniMetric(
                    title: 'Ganhos',
                    value: _formatPoints(_earnedPoints),
                    icon: Icons.trending_up_rounded,
                  ),
                  const SizedBox(width: 10),
                  _miniMetric(
                    title: 'Usados',
                    value: _formatPoints(_usedPoints),
                    icon: Icons.redeem_rounded,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context) {
    final List<_PointsClubCategory> categories = _PointsClubCategory.items;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
        ),
        itemBuilder: (context, index) {
          final _PointsClubCategory category = categories[index];
          final bool selected = category.id == _selectedCategory;

          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              setState(() => _selectedCategory = category.id);
              Future<void>.delayed(const Duration(milliseconds: 80), () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent * 0.78,
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeOutCubic,
                  );
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: selected ? _PointsClubColors.softLime : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? _PointsClubColors.primary
                      : Colors.black.withValues(alpha: 0.04),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: selected ? 0.08 : 0.04),
                    blurRadius: selected ? 18 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (category.badge != null)
                    Positioned(
                      top: -10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _PointsClubColors.purple,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _PointsClubColors.purple
                                  .withValues(alpha: 0.24),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          category.badge!,
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 34),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textMedium.copyWith(
                            color: _PointsClubColors.deepGreen,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCta(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
            );
          }
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _PointsClubColors.hotGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Text(
          'Comece a trocar pontos',
          style: textBold.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBanner(BuildContext context) {
    final List<PointsClubReward> featured = _featuredRewards;

    if (featured.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _heroController,
            itemCount: featured.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final PointsClubReward reward = featured[index];

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => _openReward(reward),
                  child: Container(
                    margin: const EdgeInsets.only(left: 18, right: 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: _PointsClubColors.deepGreen
                              .withValues(alpha: 0.12),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _rewardImage(reward, fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _PointsClubColors.deepGreen
                                      .withValues(alpha: 0.84),
                                  _PointsClubColors.primary
                                      .withValues(alpha: 0.48),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            top: 18,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _labelForType(reward.rewardType),
                                    style: textBold.copyWith(
                                      color: _PointsClubColors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _PointsClubColors.lime,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _pointsLabelForReward(reward),
                                    style: textBold.copyWith(
                                      color: _PointsClubColors.deepGreen,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reward.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textBold.copyWith(
                                    color: Colors.white,
                                    fontSize: 26,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Text(
                                    'Toque para ver detalhes',
                                    style: textMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCouponStrip(BuildContext context) {
    final List<PointsClubReward> coupons = _rewards
        .where((reward) => reward.rewardType.contains('coupon'))
        .take(4)
        .toList();

    if (coupons.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _PointsClubColors.cardSoft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Turbine sua economia com cupons',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 23,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pontos + campanhas + benefícios = mais vantagens no app',
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final PointsClubReward reward = coupons[index];

                return InkWell(
                  onTap: () => _openReward(reward),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 210,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            _PointsClubColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 56,
                            width: 56,
                            child: _rewardImage(reward, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reward.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textMedium.copyWith(
                              color: _PointsClubColors.deepGreen,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: coupons.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(BuildContext context) {
    const List<_PointsClubBenefit> benefits = [
      _PointsClubBenefit(
        icon: Icons.directions_car_filled_rounded,
        title: 'Junte pontos\nem viagens',
        available: true,
      ),
      _PointsClubBenefit(
        icon: Icons.confirmation_number_rounded,
        title: 'Troque por\ncupons',
        available: true,
      ),
      _PointsClubBenefit(
        icon: Icons.storefront_rounded,
        title: 'Use em\nparceiros',
        available: true,
      ),
      _PointsClubBenefit(
        icon: Icons.workspace_premium_rounded,
        title: 'Concorra a\nprêmios',
        available: true,
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benefícios exclusivos',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 148,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final _PointsClubBenefit benefit = benefits[index];

                return Container(
                  width: 124,
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? _PointsClubColors.softGreen
                        : _PointsClubColors.softLime,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _PointsClubColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              benefit.icon,
                              size: 42,
                              color: _PointsClubColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              benefit.title,
                              textAlign: TextAlign.center,
                              style: textMedium.copyWith(
                                color: _PointsClubColors.deepGreen,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          height: 26,
                          width: 26,
                          decoration: const BoxDecoration(
                            color: _PointsClubColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            benefit.available
                                ? Icons.check_rounded
                                : Icons.lock_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: benefits.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(BuildContext context) {
    final List<PointsClubReward> rewards = _filteredRewards;

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedCategory == 'all'
                ? 'Escolha sua recompensa'
                : _PointsClubCategory.items
                    .firstWhere(
                      (category) => category.id == _selectedCategory,
                      orElse: () => _PointsClubCategory.items.first,
                    )
                    .sectionTitle,
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use seus pontos como achar mais vantajoso.',
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          if (rewards.isEmpty)
            Container(
              margin: const EdgeInsets.only(right: 18),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Text(
                'Nenhuma recompensa disponível nessa categoria no momento.',
                style: textRegular.copyWith(color: _PointsClubColors.textSoft),
              ),
            )
          else
            SizedBox(
              height: 332,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: rewards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _RewardCard(
                    reward: rewards[index],
                    balance: _pointsBalance,
                    onTap: () => _openReward(rewards[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportShortcut(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          _reportShortcutCard(
            icon: Icons.receipt_long_rounded,
            title: 'Meus resgates',
            description:
                'Consulte vouchers, usos, validações e números da sorte.',
            onTap: _openMyVouchers,
          ),
          const SizedBox(height: 12),
          _reportShortcutCard(
            icon: Icons.timeline_rounded,
            title: 'Histórico de pontos',
            description:
                'Veja pontos ganhos, usados, bônus, corridas, entregas e marketplace.',
            onTap: _openPointsHistory,
          ),
        ],
      ),
    );
  }

  Widget _reportShortcutCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _PointsClubColors.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _PointsClubColors.primary,
                    _PointsClubColors.vibrantGreen,
                  ],
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textBold.copyWith(
                      color: _PointsClubColors.deepGreen,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: textRegular.copyWith(
                      color: _PointsClubColors.textSoft,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _PointsClubColors.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _openMyVouchers() {
    Get.to(
      () => const PointsClubVouchersScreen(),
      transition: Transition.cupertino,
    );
  }

  void _openPointsHistory() {
    Get.to(
      () => const PointsClubHistoryScreen(),
      transition: Transition.cupertino,
    );
  }

  void _openReward(PointsClubReward reward) {
    Get.to(
      () => PointsClubRewardDetailScreen(
        reward: reward,
        pointsBalance: _pointsBalance,
        onRedeem: (quantity) => _redeemReward(reward, quantity),
      ),
      transition: Transition.cupertino,
    );
  }

  void _showTermsInfo() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Clube de Pontos Lokally',
              style: textBold.copyWith(
                color: _PointsClubColors.deepGreen,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Os pontos não expiram. Eles não são dinheiro, não são saldo em carteira e não podem ser sacados. O uso acontece por benefícios, vouchers, cupons, parceiros, campanhas e números da sorte.',
              style: textRegular.copyWith(
                color: _PointsClubColors.textSoft,
                height: 1.45,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: Get.back,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _PointsClubColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Entendi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardImage(PointsClubReward reward, {BoxFit fit = BoxFit.cover}) {
    if (reward.imageUrl.isEmpty) {
      return _RewardImageFallback(rewardType: reward.rewardType);
    }

    return Image.network(
      reward.imageUrl,
      fit: fit,
      loadingBuilder: (context, child, event) {
        if (event == null) {
          return child;
        }

        return const _ImageLoading();
      },
      errorBuilder: (_, __, ___) => _RewardImageFallback(
        rewardType: reward.rewardType,
      ),
    );
  }

  Widget _roundHeroButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _floatingTicket(IconData icon, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _PointsClubColors.lime,
              _PointsClubColors.vibrantGreen,
              _PointsClubColors.primary,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _PointsClubColors.primary.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Icon(icon, color: _PointsClubColors.deepGreen, size: 28),
      ),
    );
  }

  Widget _miniMetric({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: textBold.copyWith(
                      color: Colors.white,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    title,
                    style: textRegular.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.round();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }

  static String _formatPoints(num value) {
    final String raw = value.round().toString();
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < raw.length; index++) {
      final int reverseIndex = raw.length - index;
      buffer.write(raw[index]);

      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return buffer.toString();
  }

  static String _pointsLabelForReward(PointsClubReward reward) {
    final String points = _formatPoints(reward.pointsRequired);

    if (reward.allowQuantity) {
      return '$points pts cada';
    }

    return '$points pts';
  }

  static String _periodLabel(String period) {
    switch (period) {
      case 'daily':
        return 'por dia';
      case 'weekly':
        return 'por semana';
      case 'monthly':
        return 'por mês';
      case 'lifetime':
        return 'no total';
      default:
        return period;
    }
  }

  static _PointsClubCategory _categoryForReward(String rewardType) {
    if (rewardType == 'ride_coupon') {
      return _PointsClubCategory.ride;
    }

    if (rewardType == 'parcel_coupon') {
      return _PointsClubCategory.delivery;
    }

    if (rewardType == 'marketplace_coupon') {
      return _PointsClubCategory.marketplace;
    }

    if (rewardType == 'partner_voucher') {
      return _PointsClubCategory.partners;
    }

    if (rewardType == 'lucky_number') {
      return _PointsClubCategory.lucky;
    }

    return _PointsClubCategory.prizes;
  }

  static String _labelForType(String rewardType) {
    switch (rewardType) {
      case 'ride_coupon':
        return 'Viagem';
      case 'parcel_coupon':
        return 'Entrega';
      case 'marketplace_coupon':
        return 'Marketplace';
      case 'partner_voucher':
        return 'Parceiro local';
      case 'lucky_number':
        return 'Número da sorte';
      case 'physical_reward':
        return 'Prêmio';
      case 'service_reward':
        return 'Serviço';
      default:
        return 'Benefício';
    }
  }
}

class PointsClubRewardDetailScreen extends StatefulWidget {
  final PointsClubReward reward;
  final int pointsBalance;
  final Future<void> Function(int quantity) onRedeem;

  const PointsClubRewardDetailScreen({
    super.key,
    required this.reward,
    required this.pointsBalance,
    required this.onRedeem,
  });

  @override
  State<PointsClubRewardDetailScreen> createState() =>
      _PointsClubRewardDetailScreenState();
}

class _PointsClubRewardDetailScreenState
    extends State<PointsClubRewardDetailScreen> {
  late int _quantity;
  bool _isSubmitting = false;

  PointsClubReward get reward => widget.reward;

  int get _totalPoints => reward.pointsRequired * _quantity;

  bool get _canRedeem => widget.pointsBalance >= _totalPoints;

  int get _configuredMaxQuantity {
    int max = reward.maxRedeemQuantity ?? 999;

    if (reward.stockRemaining != null && reward.stockRemaining! < max) {
      max = reward.stockRemaining!;
    }

    if (max < reward.minRedeemQuantity) {
      max = reward.minRedeemQuantity;
    }

    return max;
  }

  @override
  void initState() {
    super.initState();
    _quantity = reward.allowQuantity ? reward.minRedeemQuantity : 1;
  }

  Future<void> _submitRedeem() async {
    if (_isSubmitting || !_canRedeem) {
      return;
    }

    setState(() => _isSubmitting = true);

    await widget.onRedeem(_quantity);

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _decreaseQuantity() {
    if (!reward.allowQuantity || _quantity <= reward.minRedeemQuantity) {
      return;
    }

    setState(() => _quantity--);
  }

  void _increaseQuantity() {
    if (!reward.allowQuantity || _quantity >= _configuredMaxQuantity) {
      return;
    }

    setState(() => _quantity++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildImageHeader(context)),
            SliverToBoxAdapter(child: _buildContent(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 126)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting || !_canRedeem ? null : _submitRedeem,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canRedeem ? _PointsClubColors.hotGreen : Colors.grey.shade300,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 17),
            disabledBackgroundColor: Colors.grey.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _canRedeem
                      ? 'Trocar por ${_PointsClubHomeScreenState._formatPoints(_totalPoints)} pontos'
                      : 'Pontos insuficientes',
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return SizedBox(
      height: 370,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (reward.imageUrl.isNotEmpty)
            Image.network(
              reward.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _RewardImageFallback(rewardType: reward.rewardType),
            )
          else
            _RewardImageFallback(rewardType: reward.rewardType),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.34),
                  Colors.transparent,
                  _PointsClubColors.deepGreen.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 18,
            child: InkWell(
              onTap: Get.back,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _PointsClubColors.lime,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _PointsClubHomeScreenState._labelForType(reward.rewardType),
                    style: textBold.copyWith(
                      color: _PointsClubColors.deepGreen,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  reward.title,
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _PointsClubHomeScreenState._pointsLabelForReward(reward),
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 19,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 10),
        decoration: const BoxDecoration(
          color: _PointsClubColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _balanceBox(context),
            if (reward.allowQuantity) ...[
              const SizedBox(height: 18),
              _quantitySelector(),
            ],
            if (reward.userLimitQuantity != null &&
                reward.userLimitPeriod.isNotEmpty) ...[
              const SizedBox(height: 14),
              _limitBox(),
            ],
            const SizedBox(height: 20),
            if (reward.description.isNotEmpty) ...[
              Text(
                'Sobre a recompensa',
                style: textBold.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.description,
                style: textRegular.copyWith(
                  color: _PointsClubColors.textSoft,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
            ],
            if (reward.rules.isNotEmpty) ...[
              Text(
                'Regras de uso',
                style: textBold.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.rules,
                style: textRegular.copyWith(
                  color: _PointsClubColors.textSoft,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _PointsClubColors.softGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _PointsClubColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pontos não expiram. O voucher emitido pode ter prazo de uso conforme a regra da recompensa.',
                      style: textMedium.copyWith(
                        color: _PointsClubColors.deepGreen,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantitySelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _PointsClubColors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantidade',
                      style: textBold.copyWith(
                        color: _PointsClubColors.deepGreen,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_PointsClubHomeScreenState._formatPoints(reward.pointsRequired)} pontos por unidade',
                      style: textRegular.copyWith(
                        color: _PointsClubColors.textSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _quantityButton(
                    icon: Icons.remove_rounded,
                    enabled: _quantity > reward.minRedeemQuantity,
                    onTap: _decreaseQuantity,
                  ),
                  Container(
                    width: 58,
                    alignment: Alignment.center,
                    child: Text(
                      _quantity.toString(),
                      style: textBold.copyWith(
                        color: _PointsClubColors.deepGreen,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  _quantityButton(
                    icon: Icons.add_rounded,
                    enabled: _quantity < _configuredMaxQuantity,
                    onTap: _increaseQuantity,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _PointsClubColors.softLime,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Total desta troca: ${_PointsClubHomeScreenState._formatPoints(_totalPoints)} pontos',
              textAlign: TextAlign.center,
              style: textBold.copyWith(
                color: _PointsClubColors.deepGreen,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mínimo ${reward.minRedeemQuantity} por troca'
            '${reward.maxRedeemQuantity != null ? ' • máximo ${reward.maxRedeemQuantity}' : ''}',
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PointsClubColors.cardSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: _PointsClubColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Limite: até ${reward.userLimitQuantity} unidade(s) '
              '${_PointsClubHomeScreenState._periodLabel(reward.userLimitPeriod)}.',
              style: textMedium.copyWith(
                color: _PointsClubColors.deepGreen,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: enabled ? _PointsClubColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey.shade500,
          size: 22,
        ),
      ),
    );
  }

  Widget _balanceBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_PointsClubColors.primary, _PointsClubColors.lime],
              ),
            ),
            child: const Icon(
              Icons.diamond_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu saldo',
                  style: textRegular.copyWith(
                    color: _PointsClubColors.textSoft,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_PointsClubHomeScreenState._formatPoints(widget.pointsBalance)} pontos',
                  style: textBold.copyWith(
                    color: _PointsClubColors.deepGreen,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _canRedeem
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            color: _canRedeem
                ? _PointsClubColors.primary
                : _PointsClubColors.textSoft,
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final PointsClubReward reward;
  final int balance;
  final VoidCallback onTap;

  const _RewardCard({
    required this.reward,
    required this.balance,
    required this.onTap,
  });

  bool get _canRedeem => balance >= reward.minimumTotalPoints;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 256,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
          border: Border.all(
            color: _canRedeem
                ? _PointsClubColors.primary.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 156,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (reward.imageUrl.isNotEmpty)
                      Image.network(
                        reward.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _RewardImageFallback(rewardType: reward.rewardType),
                      )
                    else
                      _RewardImageFallback(rewardType: reward.rewardType),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _PointsClubColors.deepGreen
                              .withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          _PointsClubHomeScreenState._labelForType(
                            reward.rewardType,
                          ),
                          style: textBold.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _PointsClubColors.lime,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${_PointsClubHomeScreenState._formatPoints(reward.pointsRequired)} pts',
                          style: textBold.copyWith(
                            color: _PointsClubColors.deepGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textBold.copyWith(
                        color: _PointsClubColors.deepGreen,
                        fontSize: 18,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reward.description.isNotEmpty
                          ? reward.description
                          : 'Toque para ver detalhes e regras de uso.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textRegular.copyWith(
                        color: _PointsClubColors.textSoft,
                        height: 1.25,
                        fontSize: 13,
                      ),
                    ),
                    if (reward.allowQuantity) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _PointsClubColors.softLime,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          'Quantidade livre',
                          style: textBold.copyWith(
                            color: _PointsClubColors.deepGreen,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _canRedeem
                            ? _PointsClubColors.hotGreen
                            : _PointsClubColors.cardSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _canRedeem ? 'Trocar agora' : 'Junte mais pontos',
                        textAlign: TextAlign.center,
                        style: textBold.copyWith(
                          color: _canRedeem
                              ? Colors.white
                              : _PointsClubColors.textSoft,
                          fontSize: 14,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PointsClubVouchersScreen extends StatefulWidget {
  const PointsClubVouchersScreen({super.key});

  @override
  State<PointsClubVouchersScreen> createState() =>
      _PointsClubVouchersScreenState();
}

class _PointsClubVouchersScreenState extends State<PointsClubVouchersScreen> {
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  List<PointsClubVoucher> _items = <PointsClubVoucher>[];

  @override
  void initState() {
    super.initState();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? status = _statusForFilter(_selectedFilter);
      final Response response = await Get.find<ApiClient>().getData(
        _PointsClubEndpoints.vouchers(status: status),
      );

      if (response.statusCode == 200 && response.body is Map) {
        final Map<String, dynamic> body =
            Map<String, dynamic>.from(response.body as Map);
        final Map<String, dynamic> data =
            _PointsClubHomeScreenState._asMap(body['data']);
        final List<dynamic> rawItems = data['items'] is List
            ? List<dynamic>.from(data['items'] as List)
            : <dynamic>[];

        final List<PointsClubVoucher> parsed = rawItems
            .whereType<Map>()
            .map((item) => PointsClubVoucher.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where(_matchesSelectedFilter)
            .toList();

        if (mounted) {
          setState(() {
            _items = parsed;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Não foi possível carregar seus resgates.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível carregar seus resgates agora.';
        });
      }
    }
  }

  bool _matchesSelectedFilter(PointsClubVoucher item) {
    switch (_selectedFilter) {
      case 'coupon':
        return item.isCoupon;
      case 'voucher':
        return item.isVoucher;
      case 'lucky':
        return item.isLuckyNumber;
      case 'available':
        return item.status == 'available';
      case 'used':
        return item.status == 'used';
      case 'expired':
        return item.status == 'expired';
      default:
        return true;
    }
  }

  String? _statusForFilter(String filter) {
    switch (filter) {
      case 'available':
      case 'used':
      case 'expired':
        return filter;
      default:
        return null;
    }
  }

  void _changeFilter(String filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() => _selectedFilter = filter);
    _loadVouchers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _PointsClubColors.primary,
          onRefresh: _loadVouchers,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildFilters()),
              if (_isLoading)
                const SliverToBoxAdapter(child: _VouchersLoading())
              else if (_errorMessage != null)
                SliverToBoxAdapter(child: _buildMessage(_errorMessage!))
              else if (_items.isEmpty)
                SliverToBoxAdapter(
                  child: _buildMessage(_emptyMessage),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 36),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _items.length - 1 ? 0 : 10,
                          ),
                          child: _VoucherReportListItem(
                            item: _items[index],
                            onTap: () => Get.to(
                              () => PointsClubVoucherDetailScreen(
                                item: _items[index],
                              ),
                              transition: Transition.cupertino,
                            ),
                          ),
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _emptyMessage {
    switch (_selectedFilter) {
      case 'coupon':
        return 'Você ainda não possui cupons de desconto.';
      case 'voucher':
        return 'Você ainda não possui vouchers.';
      case 'lucky':
        return 'Você ainda não possui números da sorte.';
      case 'available':
        return 'Você ainda não possui resgates disponíveis.';
      case 'used':
        return 'Você ainda não possui resgates utilizados.';
      case 'expired':
        return 'Você ainda não possui resgates expirados.';
      default:
        return 'Você ainda não possui resgates.';
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 18,
        right: 18,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PointsClubColors.deepGreen,
            _PointsClubColors.primary,
            _PointsClubColors.vibrantGreen,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: Get.back,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _loadVouchers,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Meus resgates',
            style: textBold.copyWith(
              color: Colors.white,
              fontSize: 31,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Consulte seus cupons, vouchers e números da sorte em uma listagem simples.',
            style: textMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const List<_VoucherFilter> filters = <_VoucherFilter>[
      _VoucherFilter('all', 'Todos', Icons.apps_rounded),
      _VoucherFilter('coupon', 'Cupons', Icons.confirmation_number_outlined),
      _VoucherFilter('voucher', 'Vouchers', Icons.local_activity_rounded),
      _VoucherFilter('lucky', 'Sorteios', Icons.numbers_rounded),
      _VoucherFilter('available', 'Disponíveis', Icons.check_circle_rounded),
      _VoucherFilter('used', 'Utilizados', Icons.verified_rounded),
      _VoucherFilter('expired', 'Expirados', Icons.schedule_rounded),
    ];

    return Container(
      height: 58,
      margin: const EdgeInsets.fromLTRB(0, 18, 0, 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final _VoucherFilter filter = filters[index];
          final bool selected = filter.id == _selectedFilter;

          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _changeFilter(filter.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _PointsClubColors.deepGreen : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? _PointsClubColors.deepGreen
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: selected ? 0.09 : 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    filter.icon,
                    size: 18,
                    color: selected ? Colors.white : _PointsClubColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    filter.title,
                    style: textBold.copyWith(
                      color:
                          selected ? Colors.white : _PointsClubColors.deepGreen,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: textMedium.copyWith(
          color: _PointsClubColors.textSoft,
          fontSize: 15,
          height: 1.35,
        ),
      ),
    );
  }
}

class PointsClubHistoryScreen extends StatefulWidget {
  const PointsClubHistoryScreen({super.key});

  @override
  State<PointsClubHistoryScreen> createState() =>
      _PointsClubHistoryScreenState();
}

class _PointsClubHistoryScreenState extends State<PointsClubHistoryScreen> {
  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  List<PointsClubHistoryItem> _items = <PointsClubHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Response response = await Get.find<ApiClient>().getData(
        _PointsClubEndpoints.history(limit: 100, offset: 0),
      );

      if (response.statusCode == 200 && response.body is Map) {
        final Map<String, dynamic> body =
            Map<String, dynamic>.from(response.body as Map);
        final Map<String, dynamic> data =
            _PointsClubHomeScreenState._asMap(body['data']);
        final List<dynamic> rawItems = data['items'] is List
            ? List<dynamic>.from(data['items'] as List)
            : <dynamic>[];

        final List<PointsClubHistoryItem> parsed = rawItems
            .whereType<Map>()
            .map((item) => PointsClubHistoryItem.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where(_matchesSelectedFilter)
            .toList();

        if (mounted) {
          setState(() {
            _items = parsed;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Não foi possível carregar o histórico.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível carregar o histórico agora.';
        });
      }
    }
  }

  bool _matchesSelectedFilter(PointsClubHistoryItem item) {
    switch (_selectedFilter) {
      case 'credit':
        return item.isCredit;
      case 'debit':
        return item.isDebit;
      case 'bonus':
        return item.isBonus;
      case 'redeem':
        return item.isRedeem;
      case 'ride':
        return item.category == 'ride';
      case 'marketplace':
        return item.category == 'marketplace';
      default:
        return true;
    }
  }

  void _changeFilter(String filter) {
    if (_selectedFilter == filter) {
      return;
    }

    setState(() => _selectedFilter = filter);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _PointsClubColors.primary,
          onRefresh: _loadHistory,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildFilters()),
              if (_isLoading)
                const SliverToBoxAdapter(child: _VouchersLoading())
              else if (_errorMessage != null)
                SliverToBoxAdapter(child: _buildMessage(_errorMessage!))
              else if (_items.isEmpty)
                SliverToBoxAdapter(
                  child: _buildMessage(_emptyMessage),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 36),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _items.length - 1 ? 0 : 10,
                          ),
                          child: _HistoryReportListItem(
                            item: _items[index],
                            onTap: () => Get.to(
                              () => PointsClubHistoryDetailScreen(
                                item: _items[index],
                              ),
                              transition: Transition.cupertino,
                            ),
                          ),
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _emptyMessage {
    switch (_selectedFilter) {
      case 'credit':
        return 'Você ainda não possui pontos ganhos.';
      case 'debit':
        return 'Você ainda não possui pontos usados.';
      case 'bonus':
        return 'Você ainda não possui bônus de campanha.';
      case 'redeem':
        return 'Você ainda não possui resgates no histórico.';
      case 'ride':
        return 'Você ainda não possui pontos de viagens.';
      case 'marketplace':
        return 'Você ainda não possui pontos do marketplace.';
      default:
        return 'Você ainda não possui movimentações de pontos.';
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 18,
        right: 18,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PointsClubColors.deepGreen,
            _PointsClubColors.primary,
            _PointsClubColors.vibrantGreen,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: Get.back,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _loadHistory,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Histórico de pontos',
            style: textBold.copyWith(
              color: Colors.white,
              fontSize: 31,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Acompanhe pontos ganhos, usados, bônus de campanhas, viagens, entregas e compras no marketplace.',
            style: textMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const List<_HistoryFilter> filters = <_HistoryFilter>[
      _HistoryFilter('all', 'Todos', Icons.apps_rounded),
      _HistoryFilter('credit', 'Ganhos', Icons.add_circle_outline_rounded),
      _HistoryFilter('debit', 'Usados', Icons.remove_circle_outline_rounded),
      _HistoryFilter('bonus', 'Bônus', Icons.emoji_events_rounded),
      _HistoryFilter('redeem', 'Resgates', Icons.redeem_rounded),
      _HistoryFilter('ride', 'Viagens', Icons.directions_car_rounded),
      _HistoryFilter('marketplace', 'Marketplace', Icons.storefront_rounded),
    ];

    return Container(
      height: 62,
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final _HistoryFilter filter = filters[index];
          final bool selected = filter.id == _selectedFilter;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _changeFilter(filter.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _PointsClubColors.deepGreen : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? _PointsClubColors.deepGreen
                      : _PointsClubColors.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter.icon,
                    color: selected ? Colors.white : _PointsClubColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    filter.title,
                    style: textBold.copyWith(
                      color:
                          selected ? Colors.white : _PointsClubColors.deepGreen,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemCount: filters.length,
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 36),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _PointsClubColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: textMedium.copyWith(
                color: _PointsClubColors.textSoft,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryReportListItem extends StatelessWidget {
  final PointsClubHistoryItem item;
  final VoidCallback onTap;

  const _HistoryReportListItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = item.accentColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                item.icon,
                color: accent,
                size: 29,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : item.sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textBold.copyWith(
                      color: _PointsClubColors.deepGreen,
                      fontSize: 16,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle.isNotEmpty
                        ? item.subtitle
                        : item.createdAtLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textRegular.copyWith(
                      color: _PointsClubColors.textSoft,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _StatusPill(
                        label: item.sourceLabel,
                        status: item.isDebit ? 'used' : 'available',
                      ),
                      _StatusPill(
                        label: item.statusLabel,
                        status: item.status,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.pointsLabel,
                  style: textBold.copyWith(
                    color: item.isDebit ? Colors.redAccent : accent,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _PointsClubColors.textSoft.withValues(alpha: 0.65),
                  size: 24,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PointsClubHistoryDetailScreen extends StatelessWidget {
  final PointsClubHistoryItem item;

  const PointsClubHistoryDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildDetails()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final Color accent = item.accentColor;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 18,
        right: 18,
        bottom: 28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _PointsClubColors.deepGreen,
            accent,
            _PointsClubColors.vibrantGreen,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(42),
          bottomRight: Radius.circular(42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(item.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            item.pointsLabel,
            style: textBold.copyWith(
              color: Colors.white,
              fontSize: 29,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title.isNotEmpty ? item.title : item.sourceLabel,
            style: textBold.copyWith(
              color: Colors.white,
              fontSize: 24,
              height: 1.08,
            ),
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: textMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailCard(
            child: Column(
              children: [
                _detailLine(
                  Icons.category_rounded,
                  'Origem',
                  item.sourceLabel,
                ),
                const SizedBox(height: 12),
                _detailLine(
                  Icons.verified_rounded,
                  'Status',
                  item.statusLabel,
                ),
                if (item.createdAtLabel.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _detailLine(
                    Icons.calendar_today_rounded,
                    'Data',
                    item.createdAtLabel,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailCard(
            color: _PointsClubColors.softGreen,
            child: Column(
              children: [
                _detailLine(
                  Icons.account_balance_wallet_rounded,
                  'Saldo antes',
                  '${_PointsClubHomeScreenState._formatPoints(item.balanceBefore)} pontos',
                ),
                const SizedBox(height: 12),
                _detailLine(
                  Icons.diamond_rounded,
                  'Saldo depois',
                  '${_PointsClubHomeScreenState._formatPoints(item.balanceAfter)} pontos',
                ),
              ],
            ),
          ),
          if (item.isRedeem) ...[
            const SizedBox(height: 14),
            _redeemDetails(),
          ],
          if (item.isBonus) ...[
            const SizedBox(height: 14),
            _bonusDetails(),
          ],
          if (item.tripRefId.isNotEmpty || item.orderNumber.isNotEmpty) ...[
            const SizedBox(height: 14),
            _operationDetails(),
          ],
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descrição',
                    style: textBold.copyWith(
                      color: _PointsClubColors.deepGreen,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: textRegular.copyWith(
                      color: _PointsClubColors.textSoft,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _redeemDetails() {
    final List<String> codes = item.voucherCodes.isNotEmpty
        ? item.voucherCodes
        : (item.voucherCode.isNotEmpty
            ? <String>[item.voucherCode]
            : <String>[]);

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.isLuckyNumber ? 'Número da sorte' : 'Resgate',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          if (item.rewardTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.redeem_rounded, 'Benefício', item.rewardTitle),
          ],
          if (item.quantity != null) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.format_list_numbered_rounded,
              'Quantidade',
              '${item.quantity} unidade(s)',
            ),
          ],
          if (item.pointsPerUnit != null) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.diamond_rounded,
              'Pontos por unidade',
              '${_PointsClubHomeScreenState._formatPoints(item.pointsPerUnit!)} pontos',
            ),
          ],
          if (codes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              item.isLuckyNumber ? 'Números/códigos gerados' : 'Códigos',
              style: textBold.copyWith(
                color: _PointsClubColors.deepGreen,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...codes.map(_codeBox),
          ],
        ],
      ),
    );
  }

  Widget _bonusDetails() {
    return _DetailCard(
      color: _PointsClubColors.softLime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhes do bônus',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          if (item.campaignName.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.campaign_rounded,
              'Campanha',
              item.campaignName,
            ),
          ],
          if (item.matchTitle.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.sports_soccer_rounded,
              'Jogo',
              item.matchTitle,
            ),
          ],
          if (item.originalLedgerId.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.link_rounded,
              'Lançamento original',
              item.originalLedgerId,
            ),
          ],
        ],
      ),
    );
  }

  Widget _operationDetails() {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operação vinculada',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          if (item.tripRefId.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.local_taxi_rounded, 'Referência', item.tripRefId),
          ],
          if (item.tripType.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.route_rounded, 'Tipo', item.tripType),
          ],
          if (item.orderNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.shopping_bag_rounded,
              'Pedido',
              item.orderNumber,
            ),
          ],
          if (item.sellerName.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailLine(Icons.storefront_rounded, 'Loja', item.sellerName),
          ],
          if (item.orderTotal != null) ...[
            const SizedBox(height: 10),
            _detailLine(
              Icons.payments_rounded,
              'Total do pedido',
              "R\$ ${item.orderTotal!.toStringAsFixed(2).replaceAll('.', ',')}",
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _PointsClubColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textRegular.copyWith(
                  color: _PointsClubColors.textSoft,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textBold.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _codeBox(String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _PointsClubColors.cardSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(
        code,
        style: textBold.copyWith(
          color: _PointsClubColors.deepGreen,
          fontSize: 15,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HistoryFilter {
  final String id;
  final String title;
  final IconData icon;

  const _HistoryFilter(this.id, this.title, this.icon);
}

class PointsClubHistoryItem {
  final String id;
  final String movementType;
  final String movementLabel;
  final String sourceType;
  final String sourceLabel;
  final String sourceId;
  final String category;
  final int points;
  final String pointsLabel;
  final int balanceBefore;
  final int balanceAfter;
  final String status;
  final String statusLabel;
  final String title;
  final String subtitle;
  final String description;
  final String createdAt;
  final String createdAtLabel;
  final bool isCredit;
  final bool isDebit;
  final bool isBonus;
  final bool isRedeem;
  final bool isLuckyNumber;
  final String rewardId;
  final String rewardType;
  final String rewardTitle;
  final int? quantity;
  final int? pointsPerUnit;
  final String voucherCode;
  final List<String> voucherCodes;
  final List<String> voucherIds;
  final String campaignId;
  final String campaignName;
  final String matchId;
  final String matchTitle;
  final String originalLedgerId;
  final String tripId;
  final String tripRefId;
  final String tripType;
  final String storeOrderId;
  final String orderNumber;
  final String sellerName;
  final num? orderTotal;
  final Map<String, dynamic> metadata;

  PointsClubHistoryItem({
    required this.id,
    required this.movementType,
    required this.movementLabel,
    required this.sourceType,
    required this.sourceLabel,
    required this.sourceId,
    required this.category,
    required this.points,
    required this.pointsLabel,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.statusLabel,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.createdAt,
    required this.createdAtLabel,
    required this.isCredit,
    required this.isDebit,
    required this.isBonus,
    required this.isRedeem,
    required this.isLuckyNumber,
    required this.rewardId,
    required this.rewardType,
    required this.rewardTitle,
    required this.quantity,
    required this.pointsPerUnit,
    required this.voucherCode,
    required this.voucherCodes,
    required this.voucherIds,
    required this.campaignId,
    required this.campaignName,
    required this.matchId,
    required this.matchTitle,
    required this.originalLedgerId,
    required this.tripId,
    required this.tripRefId,
    required this.tripType,
    required this.storeOrderId,
    required this.orderNumber,
    required this.sellerName,
    required this.orderTotal,
    required this.metadata,
  });

  factory PointsClubHistoryItem.fromJson(Map<String, dynamic> json) {
    return PointsClubHistoryItem(
      id: '${json['id'] ?? ''}',
      movementType: '${json['movement_type'] ?? ''}',
      movementLabel: '${json['movement_label'] ?? ''}',
      sourceType: '${json['source_type'] ?? ''}',
      sourceLabel: '${json['source_label'] ?? ''}',
      sourceId: '${json['source_id'] ?? ''}',
      category: '${json['category'] ?? ''}',
      points: PointsClubReward._toInt(json['points']),
      pointsLabel: '${json['points_label'] ?? ''}',
      balanceBefore: PointsClubReward._toInt(json['balance_before']),
      balanceAfter: PointsClubReward._toInt(json['balance_after']),
      status: '${json['status'] ?? ''}',
      statusLabel: '${json['status_label'] ?? json['status'] ?? ''}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      description: '${json['description'] ?? ''}',
      createdAt: '${json['created_at'] ?? ''}',
      createdAtLabel: '${json['created_at_label'] ?? ''}',
      isCredit: PointsClubReward._toBool(json['is_credit']),
      isDebit: PointsClubReward._toBool(json['is_debit']),
      isBonus: PointsClubReward._toBool(json['is_bonus']),
      isRedeem: PointsClubReward._toBool(json['is_redeem']),
      isLuckyNumber: PointsClubReward._toBool(json['is_lucky_number']),
      rewardId: '${json['reward_id'] ?? ''}',
      rewardType: '${json['reward_type'] ?? ''}',
      rewardTitle: '${json['reward_title'] ?? ''}',
      quantity: PointsClubReward._toNullableInt(json['quantity']),
      pointsPerUnit: PointsClubReward._toNullableInt(json['points_per_unit']),
      voucherCode: '${json['voucher_code'] ?? ''}',
      voucherCodes: _toStringList(json['voucher_codes']),
      voucherIds: _toStringList(json['voucher_ids']),
      campaignId: '${json['campaign_id'] ?? ''}',
      campaignName: '${json['campaign_name'] ?? ''}',
      matchId: '${json['match_id'] ?? ''}',
      matchTitle: '${json['match_title'] ?? ''}',
      originalLedgerId: '${json['original_ledger_id'] ?? ''}',
      tripId: '${json['trip_id'] ?? ''}',
      tripRefId: '${json['trip_ref_id'] ?? ''}',
      tripType: '${json['trip_type'] ?? ''}',
      storeOrderId: '${json['store_order_id'] ?? ''}',
      orderNumber: '${json['order_number'] ?? ''}',
      sellerName: '${json['seller_name'] ?? ''}',
      orderTotal: _toNullableNum(json['order_total']),
      metadata: _PointsClubHomeScreenState._asMap(json['metadata']),
    );
  }

  IconData get icon {
    switch (category) {
      case 'ride':
        return Icons.directions_car_filled_rounded;
      case 'parcel':
        return Icons.local_shipping_rounded;
      case 'marketplace':
        return Icons.storefront_rounded;
      case 'bonus':
        return Icons.emoji_events_rounded;
      case 'lucky_number':
        return Icons.confirmation_number_rounded;
      case 'redeem':
        return Icons.redeem_rounded;
      case 'manual_credit':
        return Icons.add_circle_rounded;
      default:
        return isDebit ? Icons.remove_circle_rounded : Icons.diamond_rounded;
    }
  }

  Color get accentColor {
    if (isDebit) {
      return Colors.redAccent;
    }

    switch (category) {
      case 'bonus':
      case 'lucky_number':
        return _PointsClubColors.hotGreen;
      case 'marketplace':
        return _PointsClubColors.purple;
      default:
        return _PointsClubColors.primary;
    }
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => '$item')
          .where((item) => item.trim().isNotEmpty && item != 'null')
          .toList();
    }

    return <String>[];
  }

  static num? _toNullableNum(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value;
    }

    final String normalized = '$value'.trim();

    if (normalized.isEmpty || normalized == 'null') {
      return null;
    }

    return num.tryParse(normalized);
  }
}

class _VoucherReportListItem extends StatelessWidget {
  final PointsClubVoucher item;
  final VoidCallback onTap;

  const _VoucherReportListItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 62,
                width: 62,
                child: item.rewardImageUrl.isNotEmpty
                    ? Image.network(
                        item.rewardImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _RewardImageFallback(
                          rewardType: item.rewardType,
                        ),
                      )
                    : _RewardImageFallback(rewardType: item.rewardType),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.rewardTitle.isNotEmpty ? item.rewardTitle : item.kindLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textBold.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 16,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(label: item.statusLabel, status: item.status),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: _PointsClubColors.textSoft,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class PointsClubVoucherDetailScreen extends StatelessWidget {
  final PointsClubVoucher item;

  const PointsClubVoucherDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PointsClubColors.background,
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildDetails(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 330,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.rewardImageUrl.isNotEmpty)
            Image.network(
              item.rewardImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _RewardImageFallback(
                rewardType: item.rewardType,
              ),
            )
          else
            _RewardImageFallback(rewardType: item.rewardType),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.36),
                  Colors.black.withValues(alpha: 0.05),
                  _PointsClubColors.deepGreen.withValues(alpha: 0.86),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 18,
            child: InkWell(
              onTap: Get.back,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _PointsClubColors.lime,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item.kindLabel,
                        style: textBold.copyWith(
                          color: _PointsClubColors.deepGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(label: item.statusLabel, status: item.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.rewardTitle.isNotEmpty
                      ? item.rewardTitle
                      : item.kindLabel,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
        decoration: const BoxDecoration(
          color: _PointsClubColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.isLuckyNumber) _luckyNumberBox(),
            if (item.isCoupon) _couponBox(),
            if (item.isVoucher) _voucherBox(),
            if (!item.isLuckyNumber && !item.isCoupon && !item.isVoucher)
              _genericCodeBox(),
            const SizedBox(height: 16),
            _infoSection(),
            if (item.isWinner) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _PointsClubColors.deepGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.winnerText,
                  style: textBold.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _luckyNumberBox() {
    return _DetailCard(
      color: item.isWinner
          ? _PointsClubColors.lime.withValues(alpha: 0.60)
          : _PointsClubColors.softLime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.numbers_rounded,
                color: _PointsClubColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Número da sorte',
                style: textBold.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            item.luckyNumber,
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 38,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.campaignName.isNotEmpty
                ? item.campaignName
                : 'Campanha vinculada ao Clube de Pontos',
            style: textMedium.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.drawSummary,
            style: textRegular.copyWith(
              color: item.isWinner
                  ? _PointsClubColors.deepGreen
                  : _PointsClubColors.textSoft,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _couponBox() {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cupom de desconto',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use este código para aplicar desconto em uma compra no Marketplace Lokally, corrida ou entrega, conforme a regra da recompensa.',
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _selectableCode(item.voucherCode),
        ],
      ),
    );
  }

  Widget _voucherBox() {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voucher',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.partnerName.isNotEmpty
                ? 'Apresente este voucher no parceiro informado ou utilize conforme a regra da recompensa.'
                : 'Voucher de uso conforme a regra da recompensa.',
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _selectableCode(item.voucherCode),
        ],
      ),
    );
  }

  Widget _genericCodeBox() {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Código do resgate',
            style: textBold.copyWith(
              color: _PointsClubColors.deepGreen,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _selectableCode(item.voucherCode),
        ],
      ),
    );
  }

  Widget _selectableCode(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _PointsClubColors.cardSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SelectableText(
        code.isNotEmpty ? code : '-',
        style: textBold.copyWith(
          color: _PointsClubColors.deepGreen,
          fontSize: 17,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _infoSection() {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoLine(Icons.diamond_rounded, 'Pontos usados',
              '${_PointsClubHomeScreenState._formatPoints(item.pointsDebited)} pontos'),
          if (item.issuedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(
                Icons.calendar_today_rounded, 'Emissão', item.issuedAtLabel),
          ],
          if (item.expiresAtLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.schedule_rounded, 'Validade', item.expiresAtLabel),
          ],
          if (item.usedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.verified_rounded, 'Utilização', item.usedAtLabel),
          ],
          if (item.partnerName.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.storefront_rounded, 'Parceiro', item.partnerName),
          ],
          if (item.campaignWinningLuckyNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.emoji_events_rounded, 'Número sorteado',
                item.campaignWinningLuckyNumber),
          ],
          if (item.campaignDrawnAtLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(Icons.event_available_rounded, 'Sorteio',
                item.campaignDrawnAtLabel),
          ],
          if (item.campaignWinnerName.isNotEmpty ||
              item.campaignWinnerCity.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoLine(
                Icons.workspace_premium_rounded, 'Ganhador', item.winnerText),
          ],
        ],
      ),
    );
  }

  Widget _infoLine(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _PointsClubColors.primary, size: 19),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: textBold.copyWith(
            color: _PointsClubColors.deepGreen,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textRegular.copyWith(
              color: _PointsClubColors.textSoft,
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final Color? color;

  const _DetailCard({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String status;

  const _StatusPill({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color = status == 'used'
        ? _PointsClubColors.primary
        : status == 'expired' || status == 'cancelled'
            ? Colors.redAccent
            : _PointsClubColors.deepGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label.isNotEmpty ? label : status,
        style: textBold.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _VoucherFilter {
  final String id;
  final String title;
  final IconData icon;

  const _VoucherFilter(this.id, this.title, this.icon);
}

class PointsClubVoucher {
  final String id;
  final String rewardId;
  final String campaignId;
  final String partnerId;
  final String voucherCode;
  final String qrToken;
  final String luckyNumber;
  final int pointsDebited;
  final num referenceValue;
  final String status;
  final String statusLabel;
  final String issuedAt;
  final String expiresAt;
  final String usedAt;
  final String rewardTitle;
  final String rewardType;
  final String rewardImageUrl;
  final String partnerName;
  final String campaignName;
  final String campaignType;
  final String campaignDrawStatus;
  final String campaignWinningLuckyNumber;
  final String campaignWinnerName;
  final String campaignWinnerCity;
  final String campaignDrawnAt;
  final bool isWinner;

  PointsClubVoucher({
    required this.id,
    required this.rewardId,
    required this.campaignId,
    required this.partnerId,
    required this.voucherCode,
    required this.qrToken,
    required this.luckyNumber,
    required this.pointsDebited,
    required this.referenceValue,
    required this.status,
    required this.statusLabel,
    required this.issuedAt,
    required this.expiresAt,
    required this.usedAt,
    required this.rewardTitle,
    required this.rewardType,
    required this.rewardImageUrl,
    required this.partnerName,
    required this.campaignName,
    required this.campaignType,
    required this.campaignDrawStatus,
    required this.campaignWinningLuckyNumber,
    required this.campaignWinnerName,
    required this.campaignWinnerCity,
    required this.campaignDrawnAt,
    required this.isWinner,
  });

  factory PointsClubVoucher.fromJson(Map<String, dynamic> json) {
    return PointsClubVoucher(
      id: '${json['id'] ?? ''}',
      rewardId: '${json['reward_id'] ?? ''}',
      campaignId: '${json['campaign_id'] ?? ''}',
      partnerId: '${json['partner_id'] ?? ''}',
      voucherCode: '${json['voucher_code'] ?? ''}',
      qrToken: '${json['qr_token'] ?? ''}',
      luckyNumber: '${json['lucky_number'] ?? ''}',
      pointsDebited: PointsClubReward._toInt(json['points_debited']),
      referenceValue: PointsClubReward._toNum(json['reference_value']),
      status: '${json['status'] ?? ''}',
      statusLabel: '${json['status_label'] ?? json['status'] ?? ''}',
      issuedAt: '${json['issued_at'] ?? ''}',
      expiresAt: '${json['expires_at'] ?? ''}',
      usedAt: '${json['used_at'] ?? ''}',
      rewardTitle: '${json['reward_title'] ?? ''}',
      rewardType: '${json['reward_type'] ?? ''}',
      rewardImageUrl: '${json['reward_image_url'] ?? ''}',
      partnerName: '${json['partner_name'] ?? ''}',
      campaignName: '${json['campaign_name'] ?? ''}',
      campaignType: '${json['campaign_type'] ?? ''}',
      campaignDrawStatus: '${json['campaign_draw_status'] ?? ''}',
      campaignWinningLuckyNumber:
          '${json['campaign_winning_lucky_number'] ?? ''}',
      campaignWinnerName: '${json['campaign_winner_name'] ?? ''}',
      campaignWinnerCity: '${json['campaign_winner_city'] ?? ''}',
      campaignDrawnAt: '${json['campaign_drawn_at'] ?? ''}',
      isWinner: PointsClubReward._toBool(json['is_winner']),
    );
  }

  bool get isLuckyNumber =>
      rewardType == 'lucky_number' || luckyNumber.isNotEmpty;

  bool get isCoupon =>
      rewardType == 'ride_coupon' ||
      rewardType == 'parcel_coupon' ||
      rewardType == 'marketplace_coupon';

  bool get isVoucher => rewardType == 'partner_voucher';

  String get kindLabel {
    if (isLuckyNumber) {
      return 'Número da sorte';
    }

    if (isCoupon) {
      return 'Cupom de desconto';
    }

    if (isVoucher) {
      return 'Voucher';
    }

    return _PointsClubHomeScreenState._labelForType(rewardType);
  }

  String get issuedAtLabel => _dateLabel(issuedAt, prefix: 'Emitido em');

  String get expiresAtLabel => _dateLabel(expiresAt, prefix: 'Válido até');

  String get usedAtLabel => _dateLabel(usedAt, prefix: 'Utilizado em');

  String get campaignDrawnAtLabel =>
      _dateLabel(campaignDrawnAt, prefix: 'Realizado em');

  String get drawSummary {
    if (campaignDrawStatus == 'drawn') {
      if (isWinner) {
        return 'Parabéns! Este número foi sorteado.';
      }

      if (campaignWinningLuckyNumber.isNotEmpty) {
        return 'Sorteio realizado. Número sorteado: $campaignWinningLuckyNumber.';
      }

      return 'Sorteio realizado.';
    }

    if (campaignDrawStatus == 'cancelled') {
      return 'Sorteio cancelado.';
    }

    return 'Sorteio pendente.';
  }

  String get winnerText {
    final String name = campaignWinnerName.isNotEmpty
        ? campaignWinnerName
        : 'Ganhador confirmado';
    final String city =
        campaignWinnerCity.isNotEmpty ? ' • $campaignWinnerCity' : '';

    return '$name$city';
  }

  static String _dateLabel(String raw, {required String prefix}) {
    if (raw.trim().isEmpty || raw == 'null') {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return '$prefix $raw';
    }

    final DateTime local = parsed.toLocal();
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String year = local.year.toString();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '$prefix $day/$month/$year às $hour:$minute';
  }
}

class PointsClubReward {
  final String id;
  final String title;
  final String slug;
  final String imageUrl;
  final String imageAlt;
  final String rewardType;
  final int pointsRequired;
  final bool allowQuantity;
  final int minRedeemQuantity;
  final int? maxRedeemQuantity;
  final int? userLimitQuantity;
  final String userLimitPeriod;
  final int? stockQuantity;
  final int? redeemedQuantity;
  final int? stockRemaining;
  final num referenceValue;
  final String description;
  final String rules;

  PointsClubReward({
    required this.id,
    required this.title,
    required this.slug,
    required this.imageUrl,
    required this.imageAlt,
    required this.rewardType,
    required this.pointsRequired,
    required this.allowQuantity,
    required this.minRedeemQuantity,
    required this.maxRedeemQuantity,
    required this.userLimitQuantity,
    required this.userLimitPeriod,
    required this.stockQuantity,
    required this.redeemedQuantity,
    required this.stockRemaining,
    required this.referenceValue,
    required this.description,
    required this.rules,
  });

  int get minimumTotalPoints => pointsRequired * minRedeemQuantity;

  factory PointsClubReward.fromJson(Map<String, dynamic> json) {
    return PointsClubReward(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      imageUrl: '${json['image_url'] ?? ''}',
      imageAlt: '${json['image_alt'] ?? json['title'] ?? ''}',
      rewardType: '${json['reward_type'] ?? ''}',
      pointsRequired:
          _toInt(json['points_per_unit'] ?? json['points_required']),
      allowQuantity: _toBool(json['allow_quantity']),
      minRedeemQuantity: _toInt(json['min_redeem_quantity']) > 0
          ? _toInt(json['min_redeem_quantity'])
          : 1,
      maxRedeemQuantity: _toNullableInt(json['max_redeem_quantity']),
      userLimitQuantity: _toNullableInt(json['user_limit_quantity']),
      userLimitPeriod: '${json['user_limit_period'] ?? ''}',
      stockQuantity: _toNullableInt(json['stock_quantity']),
      redeemedQuantity: _toNullableInt(json['redeemed_quantity']),
      stockRemaining: _toNullableInt(json['stock_remaining']),
      referenceValue: _toNum(json['reference_value']),
      description: '${json['description'] ?? ''}',
      rules: '${json['rules'] ?? ''}',
    );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value == 1;
    }

    final String normalized = '$value'.toLowerCase().trim();

    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse('$value') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final String text = '$value'.trim();

    if (text.isEmpty || text == 'null') {
      return null;
    }

    return int.tryParse(text);
  }

  static num _toNum(dynamic value) {
    if (value is num) {
      return value;
    }

    return num.tryParse('$value') ?? 0;
  }
}

class _PointsClubCategory {
  final String id;
  final String title;
  final String sectionTitle;
  final String emoji;
  final String? badge;

  const _PointsClubCategory({
    required this.id,
    required this.title,
    required this.sectionTitle,
    required this.emoji,
    this.badge,
  });

  static const _PointsClubCategory all = _PointsClubCategory(
    id: 'all',
    title: 'Todos',
    sectionTitle: 'Todas as recompensas',
    emoji: '🎁',
  );

  static const _PointsClubCategory ride = _PointsClubCategory(
    id: 'ride',
    title: 'Viagens',
    sectionTitle: 'Cupons para viagens',
    emoji: '🚗',
  );

  static const _PointsClubCategory marketplace = _PointsClubCategory(
    id: 'marketplace',
    title: 'Loja',
    sectionTitle: 'Cupons para Marketplace',
    emoji: '🛍️',
    badge: '-25%',
  );

  static const _PointsClubCategory delivery = _PointsClubCategory(
    id: 'delivery',
    title: 'Entregas',
    sectionTitle: 'Cupons para entregas',
    emoji: '📦',
  );

  static const _PointsClubCategory partners = _PointsClubCategory(
    id: 'partners',
    title: 'Parceiros',
    sectionTitle: 'Parceiros locais',
    emoji: '🏪',
  );

  static const _PointsClubCategory lucky = _PointsClubCategory(
    id: 'lucky',
    title: 'Sorteios',
    sectionTitle: 'Números da sorte',
    emoji: '🍀',
  );

  static const _PointsClubCategory prizes = _PointsClubCategory(
    id: 'prizes',
    title: 'Prêmios',
    sectionTitle: 'Prêmios e serviços',
    emoji: '🏆',
  );

  static const List<_PointsClubCategory> items = <_PointsClubCategory>[
    all,
    ride,
    marketplace,
    delivery,
    partners,
    lucky,
    prizes,
  ];
}

class _PointsClubBenefit {
  final IconData icon;
  final String title;
  final bool available;

  const _PointsClubBenefit({
    required this.icon,
    required this.title,
    required this.available,
  });
}

class _PointsClubEndpoints {
  static const String summary = '/api/customer/points-club/summary';
  static const String rewards =
      '/api/customer/points-club/rewards?limit=50&offset=0';

  static String redeem(String id) {
    return '/api/customer/points-club/rewards/$id/redeem';
  }

  static String vouchers({String? status, int limit = 100, int offset = 0}) {
    final String statusQuery =
        status == null || status.isEmpty ? '' : '&status=$status';

    return '/api/customer/points-club/vouchers?limit=$limit&offset=$offset$statusQuery';
  }

  static String history({int limit = 100, int offset = 0}) {
    return '/api/customer/points-club/history?limit=$limit&offset=$offset';
  }
}

class _PointsClubColors {
  static const Color primary = Color(0xFF19B09E);
  static const Color vibrantGreen = Color(0xFF16D8B3);
  static const Color hotGreen = Color(0xFF00B894);
  static const Color deepGreen = Color(0xFF063B35);
  static const Color lime = Color(0xFFDAFF99);
  static const Color softLime = Color(0xFFF0FFE3);
  static const Color softGreen = Color(0xFFE7FAF6);
  static const Color cardSoft = Color(0xFFF4F7F7);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textSoft = Color(0xFF697A78);
  static const Color purple = Color(0xFF00A88F);
  static const Color softPurple = Color(0xFF12CBB0);
}

class _RewardImageFallback extends StatelessWidget {
  final String rewardType;

  const _RewardImageFallback({required this.rewardType});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (rewardType) {
      case 'ride_coupon':
        icon = Icons.directions_car_filled_rounded;
        break;
      case 'parcel_coupon':
        icon = Icons.local_shipping_rounded;
        break;
      case 'marketplace_coupon':
        icon = Icons.shopping_bag_rounded;
        break;
      case 'partner_voucher':
        icon = Icons.storefront_rounded;
        break;
      case 'lucky_number':
        icon = Icons.confirmation_number_rounded;
        break;
      default:
        icon = Icons.redeem_rounded;
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _PointsClubColors.softGreen,
            _PointsClubColors.softLime,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: _PointsClubColors.primary,
          size: 58,
        ),
      ),
    );
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _PointsClubColors.softGreen,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: _PointsClubColors.primary,
        ),
      ),
    );
  }
}

class _VouchersLoading extends StatelessWidget {
  const _VouchersLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
      child: Column(
        children: [
          for (int index = 0; index < 4; index++) ...[
            Container(
              height: 132,
              decoration: BoxDecoration(
                color: index.isEven
                    ? _PointsClubColors.softGreen
                    : _PointsClubColors.cardSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              ),
            ),
            if (index != 3) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _PointsClubLoading extends StatelessWidget {
  const _PointsClubLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 70,
        left: 22,
        right: 22,
      ),
      children: [
        Container(
          height: 270,
          decoration: BoxDecoration(
            color: _PointsClubColors.softGreen,
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 110,
          decoration: BoxDecoration(
            color: _PointsClubColors.cardSoft,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: _PointsClubColors.cardSoft,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ],
    );
  }
}

class _PointsClubError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _PointsClubError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 110,
        left: 22,
        right: 22,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: _PointsClubColors.primary,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textMedium.copyWith(
                  color: _PointsClubColors.deepGreen,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _PointsClubColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
