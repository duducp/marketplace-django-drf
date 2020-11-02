from django.http import Http404

import structlog
from drf_yasg.utils import swagger_auto_schema
from rest_framework import mixins, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.viewsets import GenericViewSet

from marketplace.apps.favorites.exceptions import (
    ClientNotFoundApiException,
    FavoriteNotFoundApiException,
    ProductNotFoundApiException,
    ProductRequestApiException
)
from marketplace.apps.favorites.models import Favorite
from marketplace.apps.favorites.serializers import FavoriteCreateSerializer
from marketplace.exceptions import Conflict

logger = structlog.get_logger(__name__)


class FavoriteListView(
    mixins.CreateModelMixin,
    GenericViewSet
):
    queryset = Favorite.objects
    serializer_class = FavoriteCreateSerializer

    @swagger_auto_schema(
        operation_summary='Adds favorite',
        request_body=FavoriteCreateSerializer,
        responses={
            201: FavoriteCreateSerializer(),
            404: 'Product or Client not found',
            400: 'Invalid body',
            409: 'Conflict',
            500: 'Internal or Product error'
        },
    )
    def create(self, request):
        try:
            logger.info(
                'Data received to create favorite',
                data=request.data
            )

            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            serializer.save()

            return Response(
                data=serializer.data,
                status=status.HTTP_201_CREATED,
                headers=self.get_success_headers(serializer.data)
            )

        except ValidationError as e:
            non_field_errors = e.detail.get('non_field_errors')
            if non_field_errors and non_field_errors[0].code == 'unique':
                raise Conflict(detail=str(non_field_errors[0]))

            client = e.detail.get('client_id')
            if client and client[0].code == 'does_not_exist':
                raise ClientNotFoundApiException()

            product = e.detail.get('product_id')
            if product and product[0].code == 'does_not_exist':
                raise ProductNotFoundApiException()
            elif product and product[0].code == 'error_request':
                raise ProductRequestApiException()

            raise


class FavoriteDetailView(
    mixins.DestroyModelMixin,
    GenericViewSet
):
    queryset = Favorite.objects

    @swagger_auto_schema(
        operation_summary='Removes favorite',
        responses={
            204: 'Success',
            404: 'Favorite not found',
        },
    )
    def destroy(self, request, pk=None):
        try:
            logger.info(
                'Request for favorite deleting',
                pk=pk
            )

            favorite = self.get_object()
            favorite.delete()

            return Response(
                status=status.HTTP_204_NO_CONTENT
            )

        except Http404:
            raise FavoriteNotFoundApiException
