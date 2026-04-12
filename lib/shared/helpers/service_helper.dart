class ServiceHelper {
  static String getLogo(String name) {
    switch (name.toLowerCase()) {
      case 'momo':
        return 'https://res.cloudinary.com/dsxdvql2r/image/upload/v1754241510/momo_o6gggy.png';
      case 'mb':
        return 'https://res.cloudinary.com/dsxdvql2r/image/upload/v1754241061/mb_rdohi1.png';
      case 'bidv':
        return 'https://res.cloudinary.com/dsxdvql2r/image/upload/v1754241062/bidv_qvmpat.png';
      case 'tikop':
        return 'https://res.cloudinary.com/dsxdvql2r/image/upload/v1754241062/tikop_smva8p.png';
      case '9999':
        return 'https://res.cloudinary.com/dsxdvql2r/image/upload/v1768034754/grok-image-dcea4d0d-0b6f-4f3e-b5e4-df405028f560_qimpjt.png';
      default:
        return 'https://cdn-icons-png.flaticon.com/512/9841/9841553.png';
    }
  }
}